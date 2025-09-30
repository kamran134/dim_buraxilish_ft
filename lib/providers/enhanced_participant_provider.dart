import 'package:flutter/material.dart';
import '../models/participant_models.dart';
import '../core/service_factory.dart';
import '../core/commands.dart';
import '../core/result.dart';
import '../repositories/participant_repository.dart';

/// Enhanced ParticipantProvider using multiple design patterns
/// - Repository Pattern: for data access abstraction
/// - Command Pattern: for operation encapsulation
/// - Result Pattern: for better error handling
/// - Factory Pattern: for dependency creation
class EnhancedParticipantProvider with ChangeNotifier {
  // Dependencies injected via Factory Pattern
  late final ParticipantRepository _repository;
  late final CommandInvoker _commandInvoker;

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

  // Constructor using Dependency Injection
  EnhancedParticipantProvider() {
    _repository = DependencyInjection.participantRepository;
    _commandInvoker = CommandInvoker();
  }

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
  List<Command> get commandHistory => _commandInvoker.history;

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message using Result pattern
  void _handleError(Exception error) {
    _errorMessage = error.toString();
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

  // Set authentication error callback
  void setAuthenticationErrorCallback(VoidCallback? callback) {
    _onAuthenticationError = callback;
  }

  // Load exam details using Result pattern
  Future<void> loadExamDetails() async {
    _setLoading(true);
    clearMessages();

    final result = await ResultUtils.tryCatchAsync(() async {
      // Get exam details from storage service
      final examDetails =
          await DependencyInjection.storageService.getExamDetails();
      if (examDetails == null) {
        throw Exception('No exam details found');
      }
      return examDetails;
    });

    result.onSuccess((examDetails) {
      _examDetails = examDetails;
      print(
          'Loaded exam details: kodBina=${examDetails.kodBina}, imtTarix=${examDetails.imtTarix}');
    }).onFailure((error) {
      _handleError(Exception('İmtahan detalları yüklənərkən xəta baş verdi'));
      _onAuthenticationError?.call();
    });

    _setLoading(false);
  }

  // Scan participant using Command pattern
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
      _handleError(Exception('Skan zamanı xəta baş verdi'));
      _screenState = ParticipantScreenState.error;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Online scanning using Command pattern
  Future<void> _scanParticipantOnline(String qrCode) async {
    if (_examDetails == null) {
      _handleError(Exception('İmtahan məlumatları tapılmadı'));
      _screenState = ParticipantScreenState.error;
      return;
    }

    // Create and execute command
    final command = ScanParticipantCommand(
      _repository,
      jobNo: qrCode,
      building: _examDetails!.kodBina ?? '0',
      examDate: _examDetails!.imtTarix ?? '',
    );

    try {
      final response = await _commandInvoker.execute(command);

      if (response.success && response.data != null) {
        _currentParticipant = response.data!;

        // Log the response message for debugging
        print('API Response message: "${response.message}"');

        // Check if participant is already registered (TƏKRAR)
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
        // Check if error is authentication related
        if (_isAuthError(response.message)) {
          print('Authentication error during scanning, redirecting to login');
          _onAuthenticationError?.call();
          return;
        }

        _handleError(Exception(response.message.isNotEmpty
            ? response.message
            : 'İştirakçı tapılmadı'));
        _screenState = ParticipantScreenState.error;
      }
    } catch (e) {
      if (_isAuthError(e.toString())) {
        print('Authentication error during scanning: $e, redirecting to login');
        _onAuthenticationError?.call();
        return;
      }

      _handleError(Exception('İnternet bağlantı problemi və ya server xətası'));
      _screenState = ParticipantScreenState.error;
    }
  }

  // Offline scanning using Command pattern
  Future<void> _scanParticipantOffline(String qrCode) async {
    final workNumber = int.tryParse(qrCode);
    if (workNumber == null) {
      _handleError(Exception('Yanlış QR kod formatı'));
      _screenState = ParticipantScreenState.error;
      return;
    }

    // Create and execute commands
    final getCommand =
        GetOfflineParticipantCommand(_repository, workNumber: workNumber);

    try {
      final participant = await _commandInvoker.execute(getCommand);

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
          // Register participant offline using another command
          final registerCommand = RegisterOfflineParticipantCommand(_repository,
              workNumber: workNumber);
          await _commandInvoker.execute(registerCommand);

          _isRepeatEntry = false;
          _setSuccess('İştirakçı qeydiyyata alındı (oflayn)');
        }

        _screenState = ParticipantScreenState.scanned;
      } else {
        _handleError(Exception('İştirakçı oflayn bazada tapılmadı'));
        _screenState = ParticipantScreenState.error;
      }
    } catch (e) {
      _handleError(Exception('Oflayn bazada axtarış zamanı xəta baş verdi'));
      _screenState = ParticipantScreenState.error;
    }
  }

  // Helper method to check authentication errors
  bool _isAuthError(String errorMessage) {
    final lowerMessage = errorMessage.toLowerCase();
    return lowerMessage.contains('401') ||
        lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('token') ||
        lowerMessage.contains('avtorizasiya');
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

  // Manual participant entry
  Future<void> enterParticipantManually(String workNumber) async {
    if (workNumber.isEmpty) {
      _handleError(Exception('İş nömrəsini daxil edin'));
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

  // Get command history for debugging
  void printCommandHistory() {
    print('Command History:');
    for (int i = 0; i < _commandInvoker.history.length; i++) {
      print('${i + 1}. ${_commandInvoker.history[i].description}');
    }
  }

  // Clear command history
  void clearCommandHistory() {
    _commandInvoker.clearHistory();
  }
}
