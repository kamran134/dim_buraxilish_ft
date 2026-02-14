import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/monitor_models.dart';
import '../services/http_service.dart';
import '../services/statistics_event_bus.dart';

/// Состояния экрана Monitor (İmtahan rəhbərləri)
enum MonitorScreenState {
  initial,
  scanning,
  scanned,
  error,
}

class MonitorProvider with ChangeNotifier {
  final HttpService _httpService = HttpService();

  // Current state
  MonitorScreenState _screenState = MonitorScreenState.initial;
  Monitor? _currentMonitor;
  String? _errorMessage;
  String? _successMessage;
  String? _monitorMessage; // Сообщение для повторных входов
  bool _isLoading = false;
  bool _isRepeatEntry = false;
  bool _isScanning = false; // Флаг для предотвращения дублирования запросов

  // Кэш последнего отсканированного кода для предотвращения быстрых дубликатов
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  static const _scanCooldownSeconds = 3;

  // Callback for authentication errors
  VoidCallback? _onAuthenticationError;

  // Getters
  MonitorScreenState get screenState => _screenState;
  Monitor? get currentMonitor => _currentMonitor;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get monitorMessage => _monitorMessage;
  bool get isLoading => _isLoading;
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
    _monitorMessage = null;
    notifyListeners();
  }

  // Set success message
  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  // Set monitor message (for repeat entries, etc.)
  void _setMonitorMessage(String message) {
    _monitorMessage = message;
    notifyListeners();
  }

  // Clear messages
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    _monitorMessage = null;
    _isRepeatEntry = false;
    notifyListeners();
  }

  // Change screen state
  void setScreenState(MonitorScreenState state) {
    _screenState = state;

    // Если переходим в режим сканирования, очищаем предыдущие данные
    if (state == MonitorScreenState.scanning) {
      _currentMonitor = null;
      _isRepeatEntry = false;
      _monitorMessage = null;
      clearMessages();
    }

    notifyListeners();
  }

  // Set authentication error callback
  void setAuthenticationErrorCallback(VoidCallback callback) {
    _onAuthenticationError = callback;
  }

  // Scan monitor QR code and get monitor info
  Future<void> scanMonitor(String qrCode) async {
    // Предотвращаем дублирование запросов
    if (_isScanning) {
      return;
    }

    // Проверяем, не сканируем ли мы тот же код слишком быстро
    final now = DateTime.now();
    if (_lastScannedCode == qrCode && _lastScanTime != null) {
      final timeDifference = now.difference(_lastScanTime!);
      if (timeDifference.inSeconds < _scanCooldownSeconds) {
        return;
      }
    }

    // Обновляем кэш последнего скана
    _lastScannedCode = qrCode;
    _lastScanTime = now;

    // Принудительно очищаем старые данные перед новым сканированием
    _currentMonitor = null;
    _isRepeatEntry = false;
    _monitorMessage = null;
    notifyListeners();

    _isScanning = true;
    _setLoading(true);
    clearMessages();
    setScreenState(MonitorScreenState.scanning);

    try {
      // First check if user is authenticated
      final token = await _httpService.getToken();
      if (token == null) {
        _isScanning = false;
        _setLoading(false);
        _onAuthenticationError?.call();
        return;
      }

      // Get exam details to get the exam date
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails == null) {
        _setError('İmtahan məlumatları tapılmadı');
        setScreenState(MonitorScreenState.error);
        _isScanning = false;
        _setLoading(false);
        return;
      }

      // Call API to scan monitor (admin doesn't need building code for scanning)
      final response = await _httpService.scanMonitor(
        workNumber: qrCode,
        examDate: examDetails.imtTarix ?? '',
      );

      if (response.success && response.data != null) {
        _currentMonitor = response.data;

        // Save monitor to local database for offline access
        await _saveMonitorToLocalDB(response.data!);

        // Check for repeat entry
        if (response.message.contains('Təkrar') ||
            response.message.toLowerCase().contains('repeat') ||
            response.message.toLowerCase().contains('təkrar')) {
          _isRepeatEntry = true;
          _setMonitorMessage('TƏKRAR GİRİŞ');
        } else {
          _isRepeatEntry = false;
          _monitorMessage = null;
        }

        setScreenState(MonitorScreenState.scanned);
        _setSuccess('İmtahan rəhbəri məlumatları uğurla oxundu');

        // Обновляем статистику через EventBus
        StatisticsEventBus()
            .notifyStatisticsUpdate('MonitorProvider.scanMonitor');
      } else {
        _setError(response.message.isNotEmpty
            ? response.message
            : 'İmtahan rəhbəri məlumatları tapılmadı');
        setScreenState(MonitorScreenState.error);
      }
    } catch (e) {
      _setError('QR kod oxunarkən xəta baş verdi');
      setScreenState(MonitorScreenState.error);
    } finally {
      _isScanning = false;
      _setLoading(false);
    }
  }

  // Reset to initial state (for next scan)
  void resetToInitial() {
    _screenState = MonitorScreenState.initial;
    _currentMonitor = null;
    _isRepeatEntry = false;
    _isScanning = false;
    clearMessages();
    notifyListeners();
  }

  // Cancel monitor registration
  Future<void> cancelRegistration() async {
    if (_currentMonitor == null) {
      _setError('Monitor məlumatları tapılmadı');
      return;
    }

    _setLoading(true);

    try {
      // Get exam details for exam date
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails == null) {
        _setError('İmtahan məlumatları tapılmadı');
        _setLoading(false);
        return;
      }

      final response = await _httpService.cancelMonitorRegistration(
        workNumber: _currentMonitor!.workNumber,
        buildingCode: _currentMonitor!.buildingCode,
        examDate: examDetails.imtTarix ?? '',
      );

      if (response.success) {
        _setSuccess(response.message);

        // Обновляем статистику после отмены регистрации
        StatisticsEventBus()
            .notifyStatisticsUpdate('MonitorProvider.cancelRegistration');

        // Return to scanning state after successful cancellation
        resetToInitial();
        setScreenState(MonitorScreenState.scanning);
      } else {
        _setError(response.message);
      }
    } catch (e) {
      _setError('Qeydiyyatı ləğv etmək mümkün olmadı');
    } finally {
      _setLoading(false);
    }
  }

  // Save monitor to local database for offline access and statistics
  Future<void> _saveMonitorToLocalDB(Monitor monitor) async {
    try {
      // TODO: Implement DatabaseService.registerMonitor method
      // final now = DateTime.now().toIso8601String();
      // await DatabaseService.registerMonitor(monitor, now);
    } catch (e) {
      // Ignore local database errors
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
