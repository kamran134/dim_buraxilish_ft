import 'package:flutter/foundation.dart';
import '../services/http_service.dart';
import '../services/database_service.dart';
import '../models/participant_models.dart';
import '../models/supervisor_models.dart';

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

  /// Check if offline data exists and get counts (like checkDownloadedOfflineDB in React Native)
  Future<void> _checkOfflineData() async {
    try {
      // Get participant count from offline database
      final participants = await DatabaseService.getAllParticipants();
      _participantCount = participants.length;
      print('Found $_participantCount participants in offline database');

      // Get supervisor count from offline database
      final supervisors = await DatabaseService.getAllSupervisors();
      _supervisorCount = supervisors.length;
      print('Found $_supervisorCount supervisors in offline database');

      // Has offline data if both participants and supervisors exist (like React Native logic)
      // React Native checks: (countEnrollees > 0) && (countSupervisors > 0)
      _hasOfflineData = _participantCount > 0 && _supervisorCount > 0;

      print(
          'Offline database status: $_hasOfflineData (participants: $_participantCount, supervisors: $_supervisorCount)');

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
  /// Follows the same pattern as React Native: participants -> supervisors -> save
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

      final buildingCode = examDetails.kodBina ?? '0';
      final examDate = examDetails.imtTarix ?? '';

      print('=== OFFLINE DATABASE DOWNLOAD DEBUG ===');
      print('Exam Details: $examDetails');
      print('Building Code: "$buildingCode"');
      print('Exam Date: "$examDate"');
      print('Building Code == "0": ${buildingCode == '0'}');
      print('Exam Date isEmpty: ${examDate.isEmpty}');
      print(
          'Starting offline database download for building: $buildingCode, date: $examDate');

      // Step 1: Download participants (like getEnrolleesByBuilding in React Native)
      print('Step 1: Downloading participants...');
      final participants = await _httpService.getParticipantsByBuilding(
        buildingCode: buildingCode,
        examDate: examDate,
      );

      if (participants.isEmpty) {
        _setError('Bu bina üçün iştirakçı məlumatları tapılmadı.');
        return;
      }

      print('Downloaded ${participants.length} participants');

      // Step 2: Download supervisors (like getSupervisorsByBuilding in React Native)
      print('Step 2: Downloading supervisors...');
      final supervisors = await _httpService.getSupervisorsByBuilding(
        buildingCode: buildingCode,
        examDate: examDate,
      );

      if (supervisors.isEmpty) {
        _setError('Bu bina üçün nəzarətçi məlumatları tapılmadı.');
        return;
      }

      print('Downloaded ${supervisors.length} supervisors');

      // Step 3: Save both to database (like saveDownloaded in React Native)
      print('Step 3: Saving to offline database...');
      await _saveOfflineData(
          participants.cast<Participant>(), supervisors.cast<Supervisor>());

      // Step 4: Update status and show success
      await _checkOfflineData();

      _setSuccess(
        'Baza uğurla telefonunuza yükləndi! ${participants.length} iştirakçı və ${supervisors.length} nəzarətçi.',
      );
    } catch (e) {
      print('Error downloading offline database: $e');
      if (e.toString().contains('401') ||
          e.toString().toLowerCase().contains('unauthorized')) {
        _setError('Avtorizasiya vaxtı bitib. Yenidən daxil olun!');
      } else if (e.toString().contains('404')) {
        _setError('Bu bina üzrə məlumat bazası tapılmadı!');
      } else {
        _setError('İnternet bağlantı yoxdur və ya server xətası!');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// Save downloaded data to offline database (like saveDownloaded in React Native)
  Future<void> _saveOfflineData(
      List<Participant> participants, List<Supervisor> supervisors) async {
    try {
      print('Clearing existing offline data...');
      // Clear existing data first (like React Native does with INSERT OR REPLACE)
      await DatabaseService.clearAllParticipants();
      await DatabaseService.clearAllSupervisors();

      print(
          'Saving ${participants.length} participants to offline database...');
      // Save participants to offline database
      await _httpService.saveParticipantsOffline(participants);

      print('Saving ${supervisors.length} supervisors to offline database...');
      // Save supervisors to offline database
      await _httpService.saveSupervisorsOffline(supervisors);

      print('Offline data saved successfully!');
    } catch (e) {
      print('Error saving offline data: $e');
      throw Exception(
          'Lokal bazaya yazılarkən xəta baş verdi: ${e.toString()}');
    }
  }

  /// Delete offline database (like deleteAllEnrollees + deleteAllSupervisors in React Native)
  Future<void> deleteOfflineDatabase() async {
    _setLoading(true);
    _clearMessages();

    try {
      print('Deleting offline database...');

      // Delete all participants (like deleteAllEnrollees in React Native)
      print('Clearing participants table...');
      await DatabaseService.clearAllParticipants();

      // Delete all supervisors (like deleteAllSupervisors in React Native)
      print('Clearing supervisors table...');
      await DatabaseService.clearAllSupervisors();

      // Clear registered data as well (clean slate)
      print('Clearing registered participants...');
      await DatabaseService.clearAllRegisteredParticipants();

      print('Clearing registered supervisors...');
      await DatabaseService.clearAllRegisteredSupervisors();

      // Update status (like checkDownloadedOfflineDB in React Native)
      await _checkOfflineData();

      _setSuccess('Lokal baza uğurla silindi.');
      print('Offline database deleted successfully!');
    } catch (e) {
      print('Error deleting offline database: $e');
      _setError('Lokal bazadan silməkdə xəta!');
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
