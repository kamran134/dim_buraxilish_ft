import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/supervisor_models.dart';
import '../services/http_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
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
  bool _isOnlineMode = true;
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

  // Toggle online/offline mode
  void toggleOnlineMode() {
    // If switching to offline mode, check if database is available
    if (_isOnlineMode && !hasOfflineDatabase) {
      _setError('Oflayn rejimə keçmək üçün əvvəlcə lokal bazanı yükləyin!');
      return;
    }

    _isOnlineMode = !_isOnlineMode;
    notifyListeners();
  }

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

  // Load supervisor details (statistics)
  Future<void> loadSupervisorDetails() async {
    _setLoading(true);
    clearMessages();

    try {
      // First check if user is authenticated
      final token = await _httpService.getToken();
      if (token == null) {
        if (kDebugMode) {
          debugPrint('[Supervisor] No JWT token found, redirecting to login');
        }
        _setLoading(false);
        _onAuthenticationError?.call();
        return;
      }

      // Get exam details to use for the request
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails != null) {
        // Try to get supervisor details from API
        final buildingCode = int.tryParse(examDetails.kodBina ?? '0') ?? 0;
        final examDate = examDetails.imtTarix ?? '';

        if (kDebugMode) {
          debugPrint(
              '[Supervisor] Loading details: buildingCode=$buildingCode, examDate=$examDate');
        }

        final supervisorDetails = await _httpService.getSupervisorDetails(
          buildingCode: buildingCode,
          examDate: examDate,
        );

        if (supervisorDetails != null) {
          _supervisorDetails = supervisorDetails;
          if (kDebugMode) {
            debugPrint(
                '[Supervisor] Loaded from API: total=${supervisorDetails.allPersonCount}, registered=${supervisorDetails.regPersonCount}');
          }
        } else {
          // Fallback to storage if API fails
          _supervisorDetails =
              await _httpService.getSupervisorDetailsFromStorage();
          if (kDebugMode) {
            debugPrint('[Supervisor] Loaded from storage');
          }
        }
      } else {
        // Fallback to storage if no exam details
        _supervisorDetails =
            await _httpService.getSupervisorDetailsFromStorage();
        if (kDebugMode) {
          debugPrint('[Supervisor] Loaded from storage (no exam details)');
        }
      }

      // If still null, use default values
      _supervisorDetails ??= const SupervisorDetails(
        allPersonCount: 0,
        regPersonCount: 0,
      );

      _setLoading(false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Supervisor] Error loading details: $e');
      }
      _setError('Nəzarətçi məlumatları yüklənə bilmədi');
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

      SupervisorResponse response;

      if (_isOnlineMode) {
        // Online mode: make API call
        response = await _httpService.scanSupervisor(
          cardNumber: qrCode,
          buildingCode: int.tryParse(examDetails.kodBina ?? '0') ?? 0,
          examDate: examDetails.imtTarix ?? '',
        );
      } else {
        // Offline mode: check local database
        response = await _httpService.getSupervisorFromOfflineDB(qrCode);

        // If supervisor found and not repeat, register offline
        if (response.success &&
            response.data != null &&
            !response.message.toLowerCase().contains('təkrar')) {
          await _httpService.registerSupervisorOffline(qrCode);
        }
      }

      if (response.success && response.data != null) {
        _currentSupervisor = response.data;

        // Check for repeat entry
        if (response.message.contains('Təkrar giriş') ||
            response.message.toLowerCase().contains('repeat') ||
            response.message.toLowerCase().contains('təkrar')) {
          _isRepeatEntry = true;
          _setSupervisorMessage('TƏKRAR GİRİŞ');
        } else {
          _isRepeatEntry = false;
          _supervisorMessage = null;

          // Save the supervisor to local database for statistics
          await _saveSupervisorToLocalDB(_currentSupervisor!);

          // Update statistics when new supervisor is registered
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

  // Save supervisor to local database for offline access and statistics
  Future<void> _saveSupervisorToLocalDB(Supervisor supervisor) async {
    try {
      final now = DateTime.now().toIso8601String();
      await DatabaseService.registerSupervisor(supervisor, now);
      print('Saved supervisor ${supervisor.cardNumber} to local database');
    } catch (e) {
      print('Error saving supervisor to local database: $e');
      // Don't show error to user, continue with normal flow
    }
  }

  // Update supervisor statistics after successful registration
  Future<void> _updateSupervisorStatistics() async {
    try {
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails != null &&
          examDetails.kodBina != null &&
          examDetails.imtTarix != null) {
        final buildingCode = int.tryParse(examDetails.kodBina!);
        if (buildingCode != null) {
          print('Updating supervisor statistics after registration');
          final updatedDetails = await _httpService.getSupervisorDetails(
            buildingCode: buildingCode,
            examDate: examDetails.imtTarix!,
          );

          if (updatedDetails != null) {
            _supervisorDetails = updatedDetails;
            print(
                'Updated supervisor statistics: registered=${updatedDetails.regPersonCount}, unregistered=${updatedDetails.unregisteredCount}');
            notifyListeners();
          }
        }
      }
    } catch (e) {
      print('Error updating supervisor statistics: $e');
      // Don't show error to user, statistics are not critical for functionality
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
      final storageService = StorageService();
      final userProfile = await storageService.getUserProfile();
      if (userProfile == null ||
          userProfile.bina == null ||
          userProfile.examDate == null) {
        _setError('İmtahan məlumatları tapılmadı');
        _setLoading(false);
        return;
      }

      final response = await _httpService.cancelSupervisorRegistration(
        cardNumber: _currentSupervisor!.cardNumber,
        buildingCode: userProfile.bina!,
        examDate: userProfile.examDate!,
      );

      print(
          'Cancel supervisor response: success=${response.success}, message=${response.message}');

      if (response.success) {
        _setSuccess(response.message);
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
