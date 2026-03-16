import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/participant_models.dart';
import '../services/http_service.dart';
import '../services/database_service.dart';
import '../services/statistics_event_bus.dart';
import '../services/sync_service.dart';
import 'offline_database_provider.dart';

class ParticipantProvider with ChangeNotifier {
  final HttpService _httpService = HttpService();

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
            await _loadStatistics(binaInt, examDetails.imtTarix!);
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

  // Load statistics from local SQLite database (no network needed)
  Future<void> _loadStatistics(int bina, String examDate) async {
    try {
      final binaStr = bina.toString();
      final stats =
          await DatabaseService.getLocalParticipantStats(binaStr, examDate);

      if (_examDetails != null) {
        final storedAllMen = _examDetails!.allManCount ?? 0;
        final storedAllWomen = _examDetails!.allWomanCount ?? 0;
        _examDetails = ExamDetails(
          adBina: _examDetails!.adBina,
          kodBina: _examDetails!.kodBina,
          imtTarix: _examDetails!.imtTarix,
          // Prefer totals from the downloaded data; fall back to local count
          allManCount:
              storedAllMen > 0 ? storedAllMen : (stats['allMen'] ?? 0),
          allWomanCount:
              storedAllWomen > 0 ? storedAllWomen : (stats['allWomen'] ?? 0),
          // Always use local registered counts (updated after every scan)
          regManCount: stats['regMen'] ?? 0,
          regWomanCount: stats['regWomen'] ?? 0,
        );
        if (kDebugMode) {
          debugPrint(
              '[Participant] Local stats — reg: ${_examDetails!.totalRegisteredCount}, not reg: ${_examDetails!.notRegisteredCount}');
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Participant] Error loading local stats: $e');
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
    _isScanning = false; // Сбрасываем флаг сканирования
    clearMessages();
    notifyListeners();
  }

  // Go to next participant
  void nextParticipant() {
    // Очищаем все данные и переходим к сканированию
    _screenState = ParticipantScreenState.scanning;
    _currentParticipant = null;
    _isRepeatEntry = false;
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
