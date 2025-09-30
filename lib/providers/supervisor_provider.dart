import 'package:flutter/material.dart';
import '../models/supervisor_models.dart';
import '../services/http_service.dart';

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
  bool _hasOfflineDatabase = false;
  bool _isRepeatEntry = false;

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
  bool get hasOfflineDatabase => _hasOfflineDatabase;
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
    notifyListeners();
  }

  // Toggle online/offline mode
  void toggleOnlineMode() {
    if (_hasOfflineDatabase) {
      _isOnlineMode = !_isOnlineMode;
      notifyListeners();
    }
  }

  // Set offline database availability
  void setOfflineDatabaseAvailability(bool available) {
    _hasOfflineDatabase = available;
    notifyListeners();
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
        print('No JWT token found, redirecting to login');
        _setLoading(false);
        _onAuthenticationError?.call();
        return;
      }

      // Load supervisor details from storage (if exists)
      // For now, we can use mock data or implement proper storage later
      // This would be similar to getSupervisorDetailsFromStorage in React Native
      _supervisorDetails = const SupervisorDetails(
        allPersonCount: 0,
        regPersonCount: 0,
      );

      _setLoading(false);
    } catch (e) {
      print('Error loading supervisor details: $e');
      _setError('Nəzarətçi məlumatları yüklənə bilmədi');
      _setLoading(false);
    }
  }

  // Scan supervisor QR code and get supervisor info
  Future<void> scanSupervisor(String qrCode) async {
    _setLoading(true);
    clearMessages();
    setScreenState(SupervisorScreenState.scanning);

    try {
      // First check if user is authenticated
      final token = await _httpService.getToken();
      if (token == null) {
        print('No JWT token found, redirecting to login');
        _setLoading(false);
        _onAuthenticationError?.call();
        return;
      }

      // Get exam details to use for the request
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails == null) {
        _setError('İmtahan məlumatları tapılmadı');
        setScreenState(SupervisorScreenState.error);
        _setLoading(false);
        return;
      }

      SupervisorResponse response;

      if (_isOnlineMode) {
        // Online mode: make API call
        response = await _httpService.scanSupervisor(
          cardNumber: qrCode,
          building: examDetails.kodBina.toString(),
          examDate: examDetails.imtTarix ?? '',
        );
      } else {
        // Offline mode: check local database
        response = await _httpService.getSupervisorFromOfflineDB(qrCode);
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
    }

    _setLoading(false);
  }

  // Reset to initial state (for next scan)
  void resetToInitial() {
    _screenState = SupervisorScreenState.initial;
    _currentSupervisor = null;
    _isRepeatEntry = false;
    clearMessages();
    notifyListeners();
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
    resetToInitial();
    setScreenState(SupervisorScreenState.scanning);
  }

  // Handle scan button press
  void handleScanButton() {
    clearSupervisorInfo();
    clearMessages();
    setScreenState(SupervisorScreenState.scanning);
  }

  // Handle error and prepare for next scan
  void handleErrorNext() {
    clearMessages();
    setScreenState(SupervisorScreenState.scanning);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
