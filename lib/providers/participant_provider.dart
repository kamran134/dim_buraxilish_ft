import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/participant_models.dart';
import '../models/violator_models.dart';
import '../services/http_service.dart';
import '../services/database_service.dart';
import '../services/statistics_event_bus.dart';
import '../services/sync_service.dart';
import 'offline_database_provider.dart';

class ParticipantProvider with ChangeNotifier {
  final HttpService _httpService = HttpService();

  ParticipantProvider() {
    // After a successful sync, pull the server-side aggregate (sum across all
    // scanners in the building). Scan events are ignored here — they recompute
    // locally inline without a network call.
    _statsBusSub = StatisticsEventBus().onStatisticsUpdate.listen((source) {
      if (source.startsWith('SyncService')) {
        refreshServerStatistics();
      }
    });
  }

  StreamSubscription<String>? _statsBusSub;

  // Server aggregate cache (null = not fetched yet this session → use local).
  int? _serverRegMen;
  int? _serverRegWomen;
  int? _serverAllMen;
  int? _serverAllWomen;

  // Current state
  ParticipantScreenState _screenState = ParticipantScreenState.initial;
  Participant? _currentParticipant;
  ExamDetails? _examDetails;
  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = false;
  // Always offline after login — no online scanning mode
  final bool _isOnlineMode = false;
  bool _isRepeatEntry = false;
  bool _isScanning = false; // Флаг для предотвращения дублирования запросов
  ViolatorInfo? _currentViolation;

  // Кэш последнего отсканированного кода для предотвращения быстрых дубликатов
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  static const _scanCooldownSeconds =
      3; // Минимальное время между сканированиями одного кода

  // Reference to OfflineDatabaseProvider
  OfflineDatabaseProvider? _offlineDatabaseProvider;

  // Callback for authentication errors
  VoidCallback? _onAuthenticationError;

  // Getters
  ParticipantScreenState get screenState => _screenState;
  Participant? get currentParticipant => _currentParticipant;
  ExamDetails? get examDetails => _examDetails;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get isLoading => _isLoading;
  bool get isOnlineMode => _isOnlineMode;
  bool get hasOfflineDatabase =>
      _offlineDatabaseProvider?.hasOfflineData ?? false;
  bool get isRepeatEntry => _isRepeatEntry;
  ViolatorInfo? get currentViolation => _currentViolation;

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message
  void _setError(String message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
  }

  // Set success message
  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  // Clear messages
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // Change screen state
  void setScreenState(ParticipantScreenState state) {
    _screenState = state;

    // Если переходим в режим сканирования, очищаем предыдущие данные
    if (state == ParticipantScreenState.scanning) {
      _currentParticipant = null;
      _isRepeatEntry = false;
      _currentViolation = null;
      clearMessages();
    }

    notifyListeners();
  }

  // No-op: online/offline toggle is removed — always works offline after login.
  void toggleOnlineMode() {}

  // Set reference to OfflineDatabaseProvider
  void setOfflineDatabaseProvider(OfflineDatabaseProvider provider) {
    _offlineDatabaseProvider = provider;
    notifyListeners();
  }

  // Initialize offline database (check if data exists)
  Future<void> initializeOfflineDatabase() async {
    // This is now handled by OfflineDatabaseProvider
    // Just refresh the status
    await _offlineDatabaseProvider?.refreshStatus();
  }

  // Load offline data (participants) - call this when user logs in or needs to sync
  Future<void> loadOfflineParticipants(List<Participant> participants) async {
    try {
      _setLoading(true);
      await _httpService.saveParticipantsOffline(participants);
      // Refresh offline database status through OfflineDatabaseProvider
      await _offlineDatabaseProvider?.refreshStatus();
      _setSuccess('${participants.length} iştirakçı oflayn bazaya yükləndi');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Participant] Error loading offline participants: $e');
      }
      _setError('Oflayn məlumatlar yüklənərkən xəta baş verdi');
    } finally {
      _setLoading(false);
    }
  }

  // Get registered participants for statistics
  Future<List<Participant>> getRegisteredParticipants() async {
    try {
      return await _httpService.getRegisteredParticipants();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Participant] Error getting registered participants: $e');
      }
      return [];
    }
  }

  // Set authentication error callback
  void setAuthenticationErrorCallback(VoidCallback? callback) {
    _onAuthenticationError = callback;
  }

  // Load exam details
  Future<void> loadExamDetails() async {
    _setLoading(true);
    clearMessages(); // Clear any previous messages

    try {
      // First check if user is authenticated
      final token = await _httpService.getToken();
      if (token == null) {
        if (kDebugMode) {
          debugPrint('[Participant] No JWT token found, redirecting to login');
        }
        _setLoading(false);
        _onAuthenticationError?.call();
        return;
      }

      // Load exam details from storage (set during login)
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails != null) {
        _examDetails = examDetails;
        print(
            'Loaded exam details: kodBina=${examDetails.kodBina}, imtTarix=${examDetails.imtTarix}');

        // Load updated statistics from API if we have building and exam date info
        if (examDetails.kodBina != null && examDetails.imtTarix != null) {
          final binaInt = int.tryParse(examDetails.kodBina!);
          if (binaInt != null) {
            // Show local numbers instantly, then overlay the server aggregate
            // (sum across all scanners) — best-effort, silent when offline.
            await _loadStatistics(binaInt, examDetails.imtTarix!);
            await refreshServerStatistics();
          }
        }

        // Don't show any success message, just load silently
      } else {
        // Try to get exam details from auth data if not in storage
        final isAuth = await _httpService.getAuth();
        if (isAuth) {
          print('Authenticated but no exam details, redirecting to login');
          _setLoading(false);
          _onAuthenticationError?.call();
        } else {
          print('Not authenticated, redirecting to login');
          _setLoading(false);
          _onAuthenticationError?.call();
        }
        return;
      }
    } catch (e) {
      print('Error loading exam details: $e');
      _setError('İmtahan detalları yüklənərkən xəta baş verdi');
    } finally {
      _setLoading(false);
    }
  }

  // Recompute the displayed statistics. When a server aggregate has been
  // fetched this session, show server-count (all scanners) + this device's
  // own not-yet-synced scans on top — so the number reflects the whole
  // building and never drops below reality between syncs. When offline / no
  // server data yet, fall back to local-only counts (this device's scans).
  Future<void> _loadStatistics(int bina, String examDate) async {
    try {
      final binaStr = bina.toString();
      final stats =
          await DatabaseService.getLocalParticipantStats(binaStr, examDate);

      if (_examDetails == null) return;

      final storedAllMen = _examDetails!.allManCount ?? 0;
      final storedAllWomen = _examDetails!.allWomanCount ?? 0;
      final localAllMen =
          storedAllMen > 0 ? storedAllMen : (stats['allMen'] ?? 0);
      final localAllWomen =
          storedAllWomen > 0 ? storedAllWomen : (stats['allWomen'] ?? 0);

      int regMen, regWomen, allMen, allWomen;
      if (_serverRegMen != null) {
        // Server aggregate + this device's pending (unsynced) scans.
        final unsynced =
            await DatabaseService.getUnsyncedParticipantGenderCounts();
        regMen = _serverRegMen! + (unsynced['men'] ?? 0);
        regWomen = _serverRegWomen! + (unsynced['women'] ?? 0);
        allMen = (_serverAllMen ?? 0) > 0 ? _serverAllMen! : localAllMen;
        allWomen = (_serverAllWomen ?? 0) > 0 ? _serverAllWomen! : localAllWomen;
      } else {
        // Offline / no server data yet — local only.
        regMen = stats['regMen'] ?? 0;
        regWomen = stats['regWomen'] ?? 0;
        allMen = localAllMen;
        allWomen = localAllWomen;
      }

      _examDetails = ExamDetails(
        adBina: _examDetails!.adBina,
        kodBina: _examDetails!.kodBina,
        imtTarix: _examDetails!.imtTarix,
        allManCount: allMen,
        allWomanCount: allWomen,
        regManCount: regMen,
        regWomanCount: regWomen,
      );
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[Participant] Error loading stats: $e');
    }
  }

  Future<void> _updateParticipantStatistics() async {
    try {
      if (_examDetails != null &&
          _examDetails!.kodBina != null &&
          _examDetails!.imtTarix != null) {
        final binaInt = int.tryParse(_examDetails!.kodBina!);
        if (binaInt != null) {
          await _loadStatistics(binaInt, _examDetails!.imtTarix!);
        }
      }
    } catch (e) {
      print('Error updating participant statistics: $e');
      // Don't show error to user, statistics are not critical for functionality
    }
  }

  /// Pull the server-side aggregate (sum across all scanners in the building)
  /// and refresh the displayed stats. No-op (keeps current numbers) when
  /// offline or the building has no server record yet.
  Future<void> refreshServerStatistics() async {
    try {
      if (_examDetails?.kodBina == null || _examDetails?.imtTarix == null) {
        return;
      }
      final bina = int.tryParse(_examDetails!.kodBina!);
      if (bina == null) return;

      final server = await _httpService.getExamDetails(
        bina: bina,
        examDate: _examDetails!.imtTarix!,
        persist: false,
      );
      if (server == null) return; // offline / not found → keep current numbers

      _serverRegMen = server.regManCount ?? 0;
      _serverRegWomen = server.regWomanCount ?? 0;
      _serverAllMen = server.allManCount ?? 0;
      _serverAllWomen = server.allWomanCount ?? 0;

      await _loadStatistics(bina, _examDetails!.imtTarix!);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Participant] refreshServerStatistics error: $e');
      }
    }
  }

  @override
  void dispose() {
    _statsBusSub?.cancel();
    super.dispose();
  }

  // Scan participant by QR code
  Future<void> scanParticipant(String qrCode) async {
    // Предотвращаем дублирование запросов
    if (_isScanning) {
      if (kDebugMode) {
        print(
            'DEBUG: Игнорируем повторный скан - предыдущий запрос еще выполняется');
      }
      return;
    }

    // Проверяем, не сканируем ли мы тот же код слишком быстро
    final now = DateTime.now();
    if (_lastScannedCode == qrCode && _lastScanTime != null) {
      final timeDifference = now.difference(_lastScanTime!);
      if (timeDifference.inSeconds < _scanCooldownSeconds) {
        if (kDebugMode) {
          print(
              'DEBUG: Игнорируем быстрое повторное сканирование того же кода (${timeDifference.inSeconds}s < $_scanCooldownSeconds s)');
        }
        return;
      }
    }

    // Обновляем кэш последнего скана
    _lastScannedCode = qrCode;
    _lastScanTime = now;

    // Принудительно очищаем старые данные перед новым сканированием
    _currentParticipant = null;
    _isRepeatEntry = false;
    _currentViolation = null;
    notifyListeners();

    _isScanning = true;
    _setLoading(true);
    clearMessages();

    try {
      await _scanParticipantOffline(qrCode);
    } catch (e) {
      _setError('Skan zamanı xəta baş verdi');
      _screenState = ParticipantScreenState.error;
    } finally {
      _isScanning = false; // Освобождаем флаг
      _setLoading(false);
      notifyListeners();
    }
  }

  // Offline participant scanning
  Future<void> _scanParticipantOffline(String qrCode) async {
    try {
      final workNumber = int.tryParse(qrCode);
      if (workNumber == null) {
        _setError('Yanlış QR kod formatı');
        _screenState = ParticipantScreenState.error;
        return;
      }

      // Query from local SQLite database
      final participant =
          await _httpService.getParticipantFromOfflineDB(workNumber);

      if (participant != null) {
        _currentParticipant = participant;

        // Check for protocol violation (silently ignore errors — field is optional)
        try {
          _currentViolation =
              await DatabaseService.getViolationForParticipant(workNumber);
        } catch (_) {
          _currentViolation = null;
        }

        // Check if already registered (for offline mode, check if qeydiyyat has today's date)
        final today = DateTime.now().toIso8601String().substring(0, 10);
        if (participant.qeydiyyat != null &&
            participant.qeydiyyat!.isNotEmpty &&
            participant.qeydiyyat != 'null' &&
            participant.qeydiyyat!.contains(today)) {
          _isRepeatEntry = true;
          _setSuccess('Bu iştirakçı artıq qeydiyyatdan keçib (oflayn)');
        } else {
          // Register participant offline
          await _httpService.registerParticipantOffline(workNumber);
          _isRepeatEntry = false;
          _setSuccess('İştirakçı qeydiyyata alındı');

          // Notify background sync service and update local statistics
          SyncService.instance.notifyScan();
          await _updateParticipantStatistics();
          StatisticsEventBus()
              .notifyStatisticsUpdate('ParticipantProvider.scan');
        }

        _screenState = ParticipantScreenState.scanned;
      } else {
        _setError('İştirakçı oflayn bazada tapılmadı');
        _screenState = ParticipantScreenState.error;
      }
    } catch (e) {
      _setError('Oflayn bazada axtarış zamanı xəta baş verdi');
      _screenState = ParticipantScreenState.error;
    }
  }

  // Manual participant entry
  Future<void> enterParticipantManually(String workNumber) async {
    if (workNumber.isEmpty) {
      _setError('İş nömrəsini daxil edin');
      return;
    }

    await scanParticipant(workNumber);
  }

  // Reset to initial state
  void reset() {
    _screenState = ParticipantScreenState.initial;
    _currentParticipant = null;
    _isRepeatEntry = false;
    _currentViolation = null;
    _isScanning = false;
    clearMessages();
    notifyListeners();
  }

  // Go to next participant
  void nextParticipant() {
    _screenState = ParticipantScreenState.scanning;
    _currentParticipant = null;
    _isRepeatEntry = false;
    _currentViolation = null;
    _isScanning = false;
    clearMessages();
    notifyListeners();
  }

  /// Cancel participant registration
  Future<void> cancelParticipantRegistration() async {
    if (_currentParticipant == null) {
      _setError('İştirakçı məlumatları tapılmadı');
      return;
    }

    _setLoading(true);
    clearMessages();

    try {
      // If this registration is still in the local sync queue (never reached
      // the server), cancel it locally without a server round-trip. Calling the
      // server would otherwise fail/no-op while the queued record would still
      // sync later → a "ghost" registration the user tried to cancel.
      final isQueued =
          await DatabaseService.isParticipantQueued(_currentParticipant!.isN);
      if (isQueued) {
        await DatabaseService.unregisterParticipant(_currentParticipant!.isN);
        // Refresh the pending counter after dropping a queued record.
        await SyncService.instance.refreshPending();
        // Recompute the displayed stats (drops the unsynced overlay).
        await _updateParticipantStatistics();
        _setSuccess('Qeydiyyat ləğv edildi');
        StatisticsEventBus()
            .notifyStatisticsUpdate('ParticipantProvider.cancelRegistration');
        nextParticipant();
        return;
      }

      final response = await _httpService.cancelParticipantRegistration(
        isN: _currentParticipant!.isN,
        bina: _currentParticipant!.bina,
        examDate: _currentParticipant!.imtTarix,
      );

      print(
          'Cancel participant response: success=${response.success}, message=${response.message}');

      if (response.success) {
        _setSuccess(response.message);

        // Remove from local statistics cache
        await DatabaseService.unregisterParticipant(_currentParticipant!.isN);

        // Server count changed → pull fresh aggregate; also recompute display.
        await refreshServerStatistics();
        await _updateParticipantStatistics();

        // Notify statistics listeners
        StatisticsEventBus()
            .notifyStatisticsUpdate('ParticipantProvider.cancelRegistration');

        // Move to next participant (which opens scanner)
        print('Moving to next participant...');
        nextParticipant();
      } else {
        _setError(response.message);
      }
    } catch (e) {
      print('Error canceling participant registration: $e');
      _setError('Qeydiyyatı ləğv etmək mümkün olmadı');
    } finally {
      _setLoading(false);
    }
  }
}
