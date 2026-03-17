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
  int _allMonitorCount = 0;
  String? _successMessage;
  String? _errorMessage;

  // Getters
  bool get isLoading => _isLoading;
  bool get hasOfflineData => _hasOfflineData;
  int get participantCount => _participantCount;
  int get supervisorCount => _supervisorCount;
  int get allMonitorCount => _allMonitorCount;
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

      // Get all_monitors count (admin offline download)
      final allMonitors = await DatabaseService.getAllMonitorsOffline();
      _allMonitorCount = allMonitors.length;
      print(
          'Found $_allMonitorCount monitors in all_monitors offline database');

      // Has offline data if monitor data OR participant+supervisor data exists
      _hasOfflineData = (_participantCount > 0 && _supervisorCount > 0) ||
          _allMonitorCount > 0;

      print(
          'Offline database status: $_hasOfflineData (participants: $_participantCount, supervisors: $_supervisorCount, monitors: $_allMonitorCount)');

      notifyListeners();
    } catch (e) {
      print('Error checking offline data: $e');
      _hasOfflineData = false;
      _participantCount = 0;
      _supervisorCount = 0;
      _allMonitorCount = 0;
      notifyListeners();
    }
  }

  /// Download offline database for admin users (only monitors)
  Future<void> downloadAdminOfflineDatabase() async {
    _setLoading(true);
    _clearMessages();

    try {
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails == null) {
        _setError('İmtahan məlumatları tapılmadı. Əvvəlcə giriş edin.');
        return;
      }

      final examDate = examDetails.imtTarix ?? '';
      if (examDate.isEmpty) {
        _setError('İmtahan tarixi tapılmadı.');
        return;
      }

      print('Admin offline download: examDate=$examDate');

      // Download ALL monitors for this exam date (admin has no building code)
      final monitors = await _httpService.getAllMonitorsInExamDate(examDate);

      if (monitors.isEmpty) {
        _setError('Bu tarix üçün monitor məlumatları tapılmadı.');
        return;
      }

      print('Downloaded ${monitors.length} monitors');

      // Clear existing and save
      await DatabaseService.clearAllMonitorsOffline();
      await DatabaseService.saveAllMonitors(monitors);

      await _checkOfflineData();

      _setSuccess('Baza uğurla yükləndi! ${monitors.length} monitor.');
    } catch (e) {
      print('Error downloading admin offline database: $e');
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
      List<Participant> participants = [];
      try {
        final result = await _httpService.getParticipantsByBuilding(
          buildingCode: buildingCode,
          examDate: examDate,
        );
        participants = result.cast<Participant>();
        print('Downloaded ${participants.length} participants');
      } catch (e) {
        print('Could not download participants, skipping: $e');
      }

      // Step 2: Download supervisors (like getSupervisorsByBuilding in React Native)
      print('Step 2: Downloading supervisors...');
      List<Supervisor> supervisors = [];
      try {
        final result = await _httpService.getSupervisorsByBuilding(
          buildingCode: buildingCode,
          examDate: examDate,
        );
        supervisors = result.cast<Supervisor>();
        print('Downloaded ${supervisors.length} supervisors');
      } catch (e) {
        print('Could not download supervisors, skipping: $e');
      }

      // Step 3: Save to database (only non-empty results)
      print('Step 3: Saving to offline database...');
      await _saveOfflineData(participants, supervisors);

      // Step 4: Update status and show success
      await _checkOfflineData();

      _setSuccess(
        'Baza uğurla telefonunuza yükləndi! ${participants.length} iştirakçı və ${supervisors.length} nəzarətçi.',
      );
    } catch (e) {
      print('Error downloading offline database: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Save downloaded data to offline database (like saveDownloaded in React Native)
  Future<void> _saveOfflineData(
      List<Participant> participants, List<Supervisor> supervisors) async {
    try {
      if (participants.isNotEmpty) {
        print('Clearing and saving ${participants.length} participants...');
        await DatabaseService.clearAllParticipants();
        await _httpService.saveParticipantsOffline(participants);
      }

      if (supervisors.isNotEmpty) {
        print('Clearing and saving ${supervisors.length} supervisors...');
        await DatabaseService.clearAllSupervisors();
        await _httpService.saveSupervisorsOffline(supervisors);
      }

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
