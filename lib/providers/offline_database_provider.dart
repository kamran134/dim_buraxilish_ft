import 'package:flutter/foundation.dart';
import '../services/http_service.dart';
import '../services/database_service.dart';

/// Provider for managing offline database operations
/// Handles downloading and deleting offline data for participants and supervisors
class OfflineDatabaseProvider extends ChangeNotifier {
  final HttpService _httpService;

  // State variables
  bool _isLoading = false;
  bool _hasOfflineData = false;
  int _participantCount = 0;
  int _supervisorCount = 0;
  String? _successMessage;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  bool get hasOfflineData => _hasOfflineData;
  int get participantCount => _participantCount;
  int get supervisorCount => _supervisorCount;
  String? get successMessage => _successMessage;
  String? get errorMessage => _errorMessage;

  OfflineDatabaseProvider({HttpService? httpService})
      : _httpService = httpService ?? HttpService() {
    _initializeOfflineDatabase();
  }

  /// Initialize offline database status
  Future<void> _initializeOfflineDatabase() async {
    try {
      await _checkOfflineData();
    } catch (e) {
      print('Error initializing offline database: $e');
    }
  }

  /// Check if offline data exists and get counts
  Future<void> _checkOfflineData() async {
    try {
      // Get participant count
      final participants = await DatabaseService.getAllParticipants();
      _participantCount = participants.length;

      // Get supervisor count  
      final supervisors = await DatabaseService.getAllSupervisors();
      _supervisorCount = supervisors.length;

      // Has offline data if both participants and supervisors exist
      _hasOfflineData = _participantCount > 0 && _supervisorCount > 0;

      notifyListeners();
    } catch (e) {
      print('Error checking offline data: $e');
      _hasOfflineData = false;
      _participantCount = 0;
      _supervisorCount = 0;
      notifyListeners();
    }
  }

  /// Download offline database (participants and supervisors)
  Future<void> downloadOfflineDatabase() async {
    _setLoading(true);
    _clearMessages();

    try {
      // Get exam details from storage first
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails == null) {
        _setError('İmtahan məlumatları tapılmadı. Əvvəlcə giriş edin.');
        return;
      }

      // Download participants
      print('Downloading participants for building: ${examDetails.kodBina}');
      final participants = await _httpService.getParticipantsByBuilding(
        buildingCode: examDetails.kodBina ?? '0',
        examDate: examDetails.imtTarix ?? '',
      );

      // Download supervisors
      print('Downloading supervisors for building: ${examDetails.kodBina}');
      final supervisors = await _httpService.getSupervisorsByBuilding(
        buildingCode: examDetails.kodBina ?? '0',
        examDate: examDetails.imtTarix ?? '',
      );

      if (participants.isNotEmpty && supervisors.isNotEmpty) {
        // Save to offline database
        await _httpService.saveParticipantsOffline(participants);
        await _httpService.saveSupervisorsOffline(supervisors);

        // Update counts and status
        await _checkOfflineData();
        
        _setSuccess(
          'Baza uğurla yükləndi! ${participants.length} iştirakçı və ${supervisors.length} nəzarətçi.',
        );
      } else {
        _setError('Bu bina üçün məlumat tapılmadı.');
      }
    } catch (e) {
      print('Error downloading offline database: $e');
      _setError('Baza yüklənərkən xəta baş verdi: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Delete offline database
  Future<void> deleteOfflineDatabase() async {
    _setLoading(true);
    _clearMessages();

    try {
      // Clear participants table
      await DatabaseService.clearAllParticipants();
      
      // Clear supervisors table
      await DatabaseService.clearAllSupervisors();

      // Clear registered participants and supervisors
      await DatabaseService.clearAllRegisteredParticipants();
      await DatabaseService.clearAllRegisteredSupervisors();

      // Update status
      await _checkOfflineData();
      
      _setSuccess('Lokal baza uğurla silindi.');
    } catch (e) {
      print('Error deleting offline database: $e');
      _setError('Baza silinərkən xəta baş verdi: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh offline data status
  Future<void> refreshStatus() async {
    await _checkOfflineData();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
    
    // Clear success message after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _successMessage = null;
      notifyListeners();
    });
  }

  void _setError(String message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
    
    // Clear error message after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _errorMessage = null;
      notifyListeners();
    });
  }

  void _clearMessages() {
    _successMessage = null;
    _errorMessage = null;
    notifyListeners();
  }
}