import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/participant_models.dart';
import '../services/http_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
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

  // Load statistics from API
  Future<void> _loadStatistics(int bina, String examDate) async {
    try {
      print('Loading statistics: bina=$bina, examDate=$examDate');

      final updatedDetails = await _httpService.getExamDetails(
        bina: bina,
        examDate: examDate,
      );

      if (updatedDetails != null) {
        _examDetails = updatedDetails;
        print('Updated exam details with statistics loaded');
        print('Total registered: ${updatedDetails.totalRegisteredCount}');
        print('Total not registered: ${updatedDetails.notRegisteredCount}');
        notifyListeners();
      }
    } catch (e) {
      print('Error loading statistics: $e');
      // Don't show error to user, statistics are not critical for functionality
    }
  }

  // Update participant statistics after successful registration
  // Save participant to local database for offline access and statistics
  Future<void> _saveParticipantToLocalDB(Participant participant) async {
    try {
      print(
          'Saving participant ${participant.isN} to local database with photo: "${participant.photo}"');
      final now = DateTime.now().toIso8601String();
      await DatabaseService.registerParticipant(participant, now);
      print('Saved participant ${participant.isN} to local database');
    } catch (e) {
      print('Error saving participant to local database: $e');
      // Don't show error to user, continue with normal flow
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
      if (_isOnlineMode) {
        await _scanParticipantOnline(qrCode);
      } else {
        await _scanParticipantOffline(qrCode);
      }
    } catch (e) {
      _setError('Skan zamanı xəta baş verdi');
      _screenState = ParticipantScreenState.error;
    } finally {
      _isScanning = false; // Освобождаем флаг
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
        print(
            'Received participant ${_currentParticipant!.isN} with photo: "${_currentParticipant!.photo}"');

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

          // Save the participant to local database for statistics
          await _saveParticipantToLocalDB(_currentParticipant!);

          // Update statistics when new participant is registered
          await _updateParticipantStatistics();
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
      final storageService = StorageService();
      final userProfile = await storageService.getUserProfile();
      if (userProfile == null ||
          userProfile.bina == null ||
          userProfile.examDate == null) {
        _setError('İmtahan məlumatları tapılmadı');
        _setLoading(false);
        return;
      }

      final response = await _httpService.cancelParticipantRegistration(
        isN: _currentParticipant!.isN,
        bina: userProfile.bina!.toString(),
        examDate: userProfile.examDate!,
      );

      print(
          'Cancel participant response: success=${response.success}, message=${response.message}');

      if (response.success) {
        _setSuccess(response.message);
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
