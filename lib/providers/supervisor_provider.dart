import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/supervisor_models.dart';
import '../services/http_service.dart';
import '../services/database_service.dart';
import '../services/statistics_event_bus.dart';
import '../services/sync_service.dart';
import 'offline_database_provider.dart';

/// Состояния экрана Supervisor
enum SupervisorScreenState {
  initial,
  scanning,
  scanned,
  error,
}

class SupervisorProvider with ChangeNotifier {
  final HttpService _httpService = HttpService();

  // Current state
  SupervisorScreenState _screenState = SupervisorScreenState.initial;
  Supervisor? _currentSupervisor;
  SupervisorDetails? _supervisorDetails;
  String? _errorMessage;
  String? _successMessage;
  String?
      _supervisorMessage; // Сообщение для повторных входов или другие статусные сообщения
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
  SupervisorScreenState get screenState => _screenState;
  Supervisor? get currentSupervisor => _currentSupervisor;
  SupervisorDetails? get supervisorDetails => _supervisorDetails;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get supervisorMessage => _supervisorMessage;
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
    _supervisorMessage = null;
    notifyListeners();
  }

  // Set success message
  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  // Set supervisor message (for repeat entries, etc.)
  void _setSupervisorMessage(String message) {
    _supervisorMessage = message;
    notifyListeners();
  }

  // Clear messages
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    _supervisorMessage = null;
    _isRepeatEntry = false;
    notifyListeners();
  }

  // Change screen state
  void setScreenState(SupervisorScreenState state) {
    _screenState = state;

    // Если переходим в режим сканирования, очищаем предыдущие данные
    if (state == SupervisorScreenState.scanning) {
      _currentSupervisor = null;
      _isRepeatEntry = false;
      _supervisorMessage = null;
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

  // Load offline data (supervisors) - call this when user logs in or needs to sync
  Future<void> loadOfflineSupervisors(List<Supervisor> supervisors) async {
    try {
      _setLoading(true);
      await _httpService.saveSupervisorsOffline(supervisors);
      // Refresh offline database status through OfflineDatabaseProvider
      await _offlineDatabaseProvider?.refreshStatus();
      _setSuccess('${supervisors.length} nəzarətçi oflayn bazaya yükləndi');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Supervisor] Error loading offline supervisors: $e');
      }
      _setError('Oflayn məlumatlar yüklənərkən xəta baş verdi');
    } finally {
      _setLoading(false);
    }
  }

  // Get registered supervisors for statistics
  Future<List<Supervisor>> getRegisteredSupervisors() async {
    try {
      return await _httpService.getRegisteredSupervisors();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Supervisor] Error getting registered supervisors: $e');
      }
      return [];
    }
  }

  // Set authentication error callback
  void setAuthenticationErrorCallback(VoidCallback? callback) {
    _onAuthenticationError = callback;
  }

  // Load supervisor details (statistics) from local SQLite DB
  Future<void> loadSupervisorDetails() async {
    _setLoading(true);
    clearMessages();

    try {
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails != null) {
        final buildingCode = int.tryParse(examDetails.kodBina ?? '0') ?? 0;
        final examDate = examDetails.imtTarix ?? '';

        if (kDebugMode) {
          debugPrint(
              '[Supervisor] Loading local stats: buildingCode=$buildingCode');
        }

        final stats = await DatabaseService.getLocalSupervisorStats(
            buildingCode, examDate);
        _supervisorDetails = SupervisorDetails(
          allPersonCount: stats['allCount'] ?? 0,
          regPersonCount: stats['regCount'] ?? 0,
          buildingCode: buildingCode,
          examDate: examDate,
        );

        if (kDebugMode) {
          debugPrint(
              '[Supervisor] Local stats — total=${_supervisorDetails!.allPersonCount}, reg=${_supervisorDetails!.regPersonCount}');
        }
      } else {
        _supervisorDetails = const SupervisorDetails(
          allPersonCount: 0,
          regPersonCount: 0,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Supervisor] Error loading local stats: $e');
      }
      _supervisorDetails ??= const SupervisorDetails(
        allPersonCount: 0,
        regPersonCount: 0,
      );
    } finally {
      _setLoading(false);
    }
  }

  // Scan supervisor QR code and get supervisor info
  Future<void> scanSupervisor(String qrCode) async {
    // Предотвращаем дублирование запросов
    if (_isScanning) {
      if (kDebugMode) {
        print(
            'DEBUG: Игнорируем повторный скан наблюдателя - предыдущий запрос еще выполняется');
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
              'DEBUG: Игнорируем быстрое повторное сканирование того же кода наблюдателя (${timeDifference.inSeconds}s < $_scanCooldownSeconds s)');
        }
        return;
      }
    }

    // Обновляем кэш последнего скана
    _lastScannedCode = qrCode;
    _lastScanTime = now;

    // Принудительно очищаем старые данные перед новым сканированием
    _currentSupervisor = null;
    _isRepeatEntry = false;
    _supervisorMessage = null;
    notifyListeners();

    _isScanning = true;
    _setLoading(true);
    clearMessages();
    setScreenState(SupervisorScreenState.scanning);

    try {
      // First check if user is authenticated
      final token = await _httpService.getToken();
      if (token == null) {
        print('No JWT token found, redirecting to login');
        _isScanning = false; // Освобождаем флаг
        _setLoading(false);
        _onAuthenticationError?.call();
        return;
      }

      // Get exam details to use for the request
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails == null) {
        _setError('İmtahan məlumatları tapılmadı');
        setScreenState(SupervisorScreenState.error);
        _isScanning = false; // Освобождаем флаг
        _setLoading(false);
        return;
      }

      // Always use offline scan path
      SupervisorResponse response =
          await _httpService.getSupervisorFromOfflineDB(qrCode);

      if (response.success && response.data != null) {
        _currentSupervisor = response.data;

        // Detect repeat: supervisor already has a registerDate set
        final alreadyRegistered =
            _currentSupervisor!.registerDate.isNotEmpty &&
                _currentSupervisor!.registerDate != 'null';

        if (alreadyRegistered) {
          _isRepeatEntry = true;
          _setSupervisorMessage('TƏKRAR GİRİŞ');
        } else {
          // New registration — save to local DB and sync queue
          await _httpService.registerSupervisorOffline(qrCode);
          _isRepeatEntry = false;
          _supervisorMessage = null;

          // Notify background sync service and update local statistics
          SyncService.instance.notifyScan();
          await _updateSupervisorStatistics();
        }

        setScreenState(SupervisorScreenState.scanned);
        _setSuccess('Nəzarətçi məlumatları uğurla oxundu');
      } else {
        _setError(response.message.isNotEmpty
            ? response.message
            : 'Nəzarətçi məlumatları tapılmadı');
        setScreenState(SupervisorScreenState.error);
      }
    } catch (e) {
      print('Error scanning supervisor: $e');
      _setError('QR kod oxunarkən xəta baş verdi');
      setScreenState(SupervisorScreenState.error);
    } finally {
      _isScanning = false; // Освобождаем флаг в любом случае
      _setLoading(false);
    }
  }

  // Reset to initial state (for next scan)
  void resetToInitial() {
    _screenState = SupervisorScreenState.initial;
    _currentSupervisor = null;
    _isRepeatEntry = false;
    _isScanning = false; // Сбрасываем флаг сканирования
    clearMessages();
    notifyListeners();
  }

  // Update supervisor statistics from local DB after registration
  Future<void> _updateSupervisorStatistics() async {
    try {
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails != null &&
          examDetails.kodBina != null &&
          examDetails.imtTarix != null) {
        final buildingCode = int.tryParse(examDetails.kodBina!);
        if (buildingCode != null) {
          final stats = await DatabaseService.getLocalSupervisorStats(
              buildingCode, examDetails.imtTarix!);
          _supervisorDetails = SupervisorDetails(
            allPersonCount: stats['allCount'] ?? 0,
            regPersonCount: stats['regCount'] ?? 0,
            buildingCode: buildingCode,
            examDate: examDetails.imtTarix,
          );
          if (kDebugMode) {
            debugPrint(
                '[Supervisor] Stats updated — reg=${_supervisorDetails!.regPersonCount}');
          }
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Supervisor] Stats update error: $e');
    }
  }

  // Clear supervisor info
  void clearSupervisorInfo() {
    _currentSupervisor = null;
    _isRepeatEntry = false;
    _supervisorMessage = null;
    notifyListeners();
  }

  // Handle next button press (reset and prepare for next scan)
  void handleNextButton() {
    // Очищаем все данные и переходим к сканированию
    _screenState = SupervisorScreenState.scanning;
    _currentSupervisor = null;
    _isRepeatEntry = false;
    _isScanning = false;
    _supervisorMessage = null;
    clearMessages();
    notifyListeners();
  }

  // Handle scan button press
  void handleScanButton() {
    // Очищаем все данные и переходим к сканированию
    _screenState = SupervisorScreenState.scanning;
    _currentSupervisor = null;
    _isRepeatEntry = false;
    _isScanning = false;
    _supervisorMessage = null;
    clearMessages();
    notifyListeners();
  }

  // Handle error and prepare for next scan
  void handleErrorNext() {
    clearMessages();
    setScreenState(SupervisorScreenState.scanning);
  }

  /// Cancel supervisor registration
  Future<void> cancelSupervisorRegistration() async {
    if (_currentSupervisor == null) {
      _setError('Nəzarətçi məlumatları tapılmadı');
      return;
    }

    _setLoading(true);
    clearMessages();

    try {
      final response = await _httpService.cancelSupervisorRegistration(
        cardNumber: _currentSupervisor!.cardNumber,
        buildingCode: _currentSupervisor!.buildingCode,
        examDate: _currentSupervisor!.examDate,
      );

      print(
          'Cancel supervisor response: success=${response.success}, message=${response.message}');

      if (response.success) {
        _setSuccess(response.message);

        // Remove from local statistics cache
        await DatabaseService.unregisterSupervisor(
            _currentSupervisor!.cardNumber);

        // Notify statistics listeners
        StatisticsEventBus()
            .notifyStatisticsUpdate('SupervisorProvider.cancelRegistration');

        // Return to scanning state after successful cancellation
        print('Returning to scanning state...');
        resetToInitial();
        setScreenState(SupervisorScreenState.scanning);
      } else {
        _setError(response.message);
      }
    } catch (e) {
      print('Error canceling supervisor registration: $e');
      _setError('Qeydiyyatı ləğv etmək mümkün olmadı');
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
