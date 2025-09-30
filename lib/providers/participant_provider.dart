import 'package:flutter/material.dart';
import '../models/participant_models.dart';
import '../services/http_service.dart';

class ParticipantProvider with ChangeNotifier {
  final HttpService _httpService = HttpService();

  // Current state
  ParticipantScreenState _screenState = ParticipantScreenState.initial;
  Participant? _currentParticipant;
  ExamDetails? _examDetails;
  String? _errorMessage;
  String? _successMessage;
  bool _isLoading = false;
  bool _isOnlineMode = true;
  bool _hasOfflineDatabase = false;
  bool _isRepeatEntry = false;

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

  // Load exam details
  Future<void> loadExamDetails() async {
    _setLoading(true);
    clearMessages(); // Clear any previous messages

    try {
      // First check if user is authenticated
      final token = await _httpService.getToken();
      if (token == null) {
        print('No JWT token found, redirecting to login');
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

  // Scan participant by QR code
  Future<void> scanParticipant(String qrCode) async {
    _setLoading(true);
    clearMessages();

    try {
      if (_isOnlineMode) {
        await _scanParticipantOnline(qrCode);
      } else {
        await _scanParticipantOffline(qrCode);
      }
    } catch (e) {
      _setError('Skan zamanı xəta baş verdi');
      _screenState = ParticipantScreenState.error;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Online participant scanning
  Future<void> _scanParticipantOnline(String qrCode) async {
    try {
      if (_examDetails == null) {
        _setError('İmtahan məlumatları tapılmadı');
        _screenState = ParticipantScreenState.error;
        return;
      }

      // Call actual API endpoint from React Native project
      final response = await _httpService.scanParticipant(
        jobNo: qrCode,
        building: _examDetails!.kodBina ?? '0',
        examDate: _examDetails!.imtTarix ?? '',
      );

      if (response.success && response.data != null) {
        _currentParticipant = response.data!;

        // Log the response message for debugging
        print('API Response message: "${response.message}"');

        // Check if participant is already registered (TƏKRAR)
        // Convert to lowercase for case-insensitive comparison
        final messageLower = response.message.toLowerCase();
        if (messageLower == 'təkrar' ||
            messageLower.contains('təkrar') ||
            messageLower == 'tekrar' ||
            messageLower.contains('tekrar')) {
          _isRepeatEntry = true;
          print('Detected repeat entry');
          _setSuccess('Bu iştirakçı artıq qeydiyyatdan keçib');
        } else {
          _isRepeatEntry = false;
          print('New participant registration');
          _setSuccess('İştirakçı tapıldı və qeydiyyata alındı');
        }

        _screenState = ParticipantScreenState.scanned;
      } else {
        // Check if error is related to authentication
        if (response.message.contains('401') ||
            response.message.contains('Unauthorized') ||
            response.message.contains('Token') ||
            response.message.toLowerCase().contains('avtorizasiya')) {
          print('Authentication error during scanning, redirecting to login');
          _onAuthenticationError?.call();
          return;
        }

        _setError(response.message.isNotEmpty
            ? response.message
            : 'İştirakçı tapılmadı');
        _screenState = ParticipantScreenState.error;
      }
    } catch (e) {
      final errorMessage = e.toString();
      // Check if error is authentication related
      if (errorMessage.contains('401') ||
          errorMessage.contains('Unauthorized') ||
          errorMessage.contains('Token expired') ||
          errorMessage.toLowerCase().contains('avtorizasiya')) {
        print('Authentication error during scanning: $e, redirecting to login');
        _onAuthenticationError?.call();
        return;
      }

      _setError('İnternet bağlantı problemi və ya server xətası');
      _screenState = ParticipantScreenState.error;
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
          _setSuccess('İştirakçı qeydiyyata alındı (oflayn)');
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
    clearMessages();
    notifyListeners();
  }

  // Go to next participant
  void nextParticipant() {
    reset();
  }
}
