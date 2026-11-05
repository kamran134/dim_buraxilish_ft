import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/http_service.dart';
import '../services/photo_download_runner.dart';
import '../utils/app_version.dart';
import '../services/database_service.dart';
import '../models/participant_models.dart';
import '../models/supervisor_models.dart';
import '../models/violator_models.dart';
import '../models/monitor_models.dart';

enum OfflineDownloadResult { success, partialSuccess, emptyData, networkError }

/// Which part of [OfflineDatabaseProvider.downloadOfflineDatabase] is running,
/// so the progress widget can show an indeterminate bar for the lists and a
/// determinate one for the photos.
enum OfflineDownloadPhase { data, photos }

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
  int? _photosDone;
  int? _photosTotal;
  OfflineDownloadPhase? _downloadPhase;
  bool _photosRetrying = false;

  // Getters
  bool get isLoading => _isLoading;
  bool get hasOfflineData => _hasOfflineData;
  int get participantCount => _participantCount;
  int get supervisorCount => _supervisorCount;
  int get allMonitorCount => _allMonitorCount;
  String? get successMessage => _successMessage;
  String? get errorMessage => _errorMessage;
  // Progress of the photo download — null until it starts.
  int? get photosDone => _photosDone;
  int? get photosTotal => _photosTotal;
  // Null while no download runs.
  OfflineDownloadPhase? get downloadPhase => _downloadPhase;
  // True while a failed photo round is waiting to be retried.
  bool get photosRetrying => _photosRetrying;

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
      // COUNT(*) only — loading the rows just to count them pulled every
      // photo into memory.
      final counts = await DatabaseService.getOfflineTableCounts();
      _participantCount = counts['participants'] ?? 0;
      print('Found $_participantCount participants in offline database');

      _supervisorCount = counts['supervisors'] ?? 0;
      print('Found $_supervisorCount supervisors in offline database');

      // all_monitors (admin offline download)
      _allMonitorCount = counts['allMonitors'] ?? 0;
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
  ///
  /// Returns [OfflineDownloadResult.emptyData] when the slot has no monitors
  /// at all (not an error — the admin may continue without them),
  /// [OfflineDownloadResult.networkError] with [errorMessage] set on failure.
  Future<OfflineDownloadResult> downloadAdminOfflineDatabase() async {
    _setLoading(true);
    _clearMessages();

    try {
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails == null) {
        _setError('İmtahan məlumatları tapılmadı. Əvvəlcə giriş edin.');
        return OfflineDownloadResult.networkError;
      }

      final slotKey = examDetails.slotKey ?? '';
      if (slotKey.isEmpty) {
        _setError('İmtahan slotu tapılmadı.');
        return OfflineDownloadResult.networkError;
      }

      // Download ALL monitors for the active slot (admin has no building code)
      List<Monitor> monitors;
      try {
        monitors = await _httpService.getAllMonitors();
      } on DioException catch (e) {
        if (e.response?.statusCode == 400) {
          // Invalid `X-Exam-Slot` header — never fall through to saving
          // anything for this stale/wrong slot.
          _setError(_slotErrorMessage(e));
          return OfflineDownloadResult.networkError;
        }
        rethrow;
      }

      if (monitors.isEmpty) {
        await DatabaseService.clearAllMonitorsOffline();
        await _checkOfflineData();
        return OfflineDownloadResult.emptyData;
      }

      print('Downloaded ${monitors.length} monitors');

      // Clear existing and save
      await DatabaseService.clearAllMonitorsOffline();
      await DatabaseService.saveAllMonitors(monitors);

      await _checkOfflineData();

      _setSuccess('Baza uğurla yükləndi! ${monitors.length} monitor.');
      return OfflineDownloadResult.success;
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
      return OfflineDownloadResult.networkError;
    } finally {
      _setLoading(false);
    }
  }

  /// Download offline database (participants and supervisors, then photos).
  /// Returns [OfflineDownloadResult] so the caller can react without relying
  /// on the provider's error/success message state.
  ///
  /// The download is all-or-nothing from the user's point of view: a stage
  /// marker (see [OfflineDownloadStage]) is kept in secure storage from just
  /// before the lists are saved until every photo is in, so an interrupted
  /// run resumes with the photos on the next launch instead of letting the
  /// user in with incomplete data. The screen stays awake meanwhile.
  Future<OfflineDownloadResult> downloadOfflineDatabase() async {
    _setLoading(true);
    _clearMessages();
    _photosDone = null;
    _photosTotal = null;
    _photosRetrying = false;
    _downloadPhase = OfflineDownloadPhase.data;
    notifyListeners();
    _enableWakelock();

    try {
      final examDetails = await _httpService.getExamDetailsFromStorage();
      if (examDetails == null) {
        _setError('İmtahan məlumatları tapılmadı. Əvvəlcə giriş edin.');
        return OfflineDownloadResult.networkError;
      }

      final buildingCode = examDetails.buildingCode ?? '0';

      // A previous run got the lists saved but not all photos: skip straight
      // to the photos.
      final stage = await _httpService.getOfflineDownloadStage();
      final counts = await DatabaseService.getOfflineTableCounts();
      final resumePhotos = stage == OfflineDownloadStage.photos &&
          (counts['participants'] ?? 0) > 0;

      if (!resumePhotos) {
        bool hadNetworkError = false;

        // Step 1: participants (light — no photos; those come in step 5)
        List<Participant> participants = [];
        try {
          participants = await _httpService.getParticipantsLightByBuilding(
            buildingCode: buildingCode,
          );
          print('Downloaded ${participants.length} participants');
        } on DioException catch (e) {
          if (e.response?.statusCode == 400) {
            // Invalid `X-Exam-Slot` header — abort outright, never save a
            // silently-partial database for the wrong slot.
            _setError(_slotErrorMessage(e));
            return OfflineDownloadResult.networkError;
          }
          print('Could not download participants: $e');
          hadNetworkError = true;
        } catch (e) {
          print('Could not download participants: $e');
          hadNetworkError = true;
        }

        // Step 2: supervisors
        List<Supervisor> supervisors = [];
        try {
          final result = await _httpService.getSupervisorsByBuilding(
            buildingCode: buildingCode,
          );
          supervisors = result.cast<Supervisor>();
          print('Downloaded ${supervisors.length} supervisors');
        } on DioException catch (e) {
          if (e.response?.statusCode == 400) {
            _setError(_slotErrorMessage(e));
            return OfflineDownloadResult.networkError;
          }
          print('Could not download supervisors: $e');
          hadNetworkError = true;
        } catch (e) {
          print('Could not download supervisors: $e');
          hadNetworkError = true;
        }

        // Step 3: violators (always optional — never blocks)
        List<ViolatorInfo> violators = [];
        try {
          violators = await _httpService.getViolatorsInBuilding(
            buildingCode: buildingCode,
          );
          print('Downloaded ${violators.length} violators');
        } catch (e) {
          print('Could not download violators, skipping: $e');
        }

        // A half-loaded database is never saved: the old data (if any) stays
        // untouched and no stage marker is set.
        if (hadNetworkError) {
          _setError('İnternet bağlantısı kəsildi. Yenidən cəhd edin.');
          return OfflineDownloadResult.networkError;
        }

        // Step 4: save (participants land in SQLite first, without photos —
        // the photo UPDATE below needs existing card_number rows to match).
        // The marker goes up right before the old data is replaced and flips
        // to `photos` once the lists are in.
        await _httpService.setOfflineDownloadStage(OfflineDownloadStage.data);
        await _saveOfflineData(participants, supervisors, violators);
        await _httpService.setOfflineDownloadStage(OfflineDownloadStage.photos);
      }

      await _checkOfflineData();

      if (_participantCount == 0 && _supervisorCount == 0) {
        // The marker stays: a relaunch retries the whole download.
        return OfflineDownloadResult.emptyData;
      }

      // Step 5: photos. Without participants there is nothing to attach them to.
      if (_participantCount > 0) {
        _downloadPhase = OfflineDownloadPhase.photos;
        notifyListeners();

        final failure = await _downloadPhotos(buildingCode);
        if (failure != null) return failure;
      }
      await _httpService.clearOfflineDownloadStage();

      // One of them is missing — the server really returned an empty list.
      if (_participantCount == 0 || _supervisorCount == 0) {
        return OfflineDownloadResult.partialSuccess;
      }

      _setSuccess(
        'Baza uğurla telefonunuza yükləndi! $_participantCount iştirakçı və $_supervisorCount nəzarətçi.',
      );
      return OfflineDownloadResult.success;
    } catch (e) {
      print('Error downloading offline database: $e');
      _setError('Yükləmə zamanı xəta baş verdi');
      return OfflineDownloadResult.networkError;
    } finally {
      _disableWakelock();
      _photosRetrying = false;
      _downloadPhase = null;
      _setLoading(false);
    }
  }

  /// Runs the parallel photo download for everything still missing. Returns
  /// null when all photos are stored, otherwise the result to hand back (the
  /// error message is already set).
  Future<OfflineDownloadResult?> _downloadPhotos(String buildingCode) async {
    final runner = PhotoDownloadRunner(
      loadMissing: DatabaseService.getCardNumbersWithoutPhoto,
      fetchPart: (cards, onBatch) => _httpService.fetchParticipantPhotos(
        buildingCode: buildingCode,
        cardNumbers: cards,
        onBatch: onBatch,
      ),
      saveBatch: DatabaseService.updateParticipantPhotos,
      isFatal: _isFatalPhotoError,
      totalParticipants: _participantCount,
      onProgress: (done, total) {
        _photosDone = done;
        _photosTotal = total;
        _photosRetrying = false;
        notifyListeners();
      },
      onRetry: () {
        _photosRetrying = true;
        notifyListeners();
      },
    );

    try {
      final complete = await runner.run();
      if (!complete) {
        _setError(
            'Şəkillər tam yüklənmədi: ${_photosDone ?? 0} / ${_photosTotal ?? 0}. İnternet bağlantısını yoxlayıb yenidən cəhd edin.');
        return OfflineDownloadResult.networkError;
      }
      return null;
    } on DioException catch (e) {
      print('Photo download aborted: $e');
      switch (e.response?.statusCode) {
        case 400:
          _setError(_slotErrorMessage(e));
        case 401:
          _setError('Avtorizasiya vaxtı bitib. Yenidən daxil olun!');
        default:
          _setError('Yükləmə zamanı xəta baş verdi');
      }
      return OfflineDownloadResult.networkError;
    }
  }

  /// Retrying cannot fix a rejected slot (400), an expired session (401) or a
  /// forbidden role (403).
  static bool _isFatalPhotoError(Object error) {
    if (error is! DioException) return false;
    final status = error.response?.statusCode;
    return status == 400 || status == 401 || status == 403;
  }

  // The plugin may be missing or fail on some devices — never let that break
  // the download itself.
  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      print('Could not enable wakelock: $e');
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      print('Could not disable wakelock: $e');
    }
  }

  /// Save downloaded data to offline database (like saveDownloaded in React Native)
  ///
  /// Calls [DatabaseService.saveParticipants] directly rather than
  /// [HttpService.saveParticipantsOffline], which swallows write errors — here
  /// a failed write must abort the download.
  Future<void> _saveOfflineData(
      List<Participant> participants,
      List<Supervisor> supervisors,
      List<ViolatorInfo> violators) async {
    try {
      if (participants.isNotEmpty) {
        print('Clearing and saving ${participants.length} participants...');
        await DatabaseService.clearAllParticipants();
        await DatabaseService.saveParticipants(participants);
      }

      if (supervisors.isNotEmpty) {
        print('Clearing and saving ${supervisors.length} supervisors...');
        await DatabaseService.clearAllSupervisors();
        await _httpService.saveSupervisorsOffline(supervisors);
      }

      // Always overwrite violations (empty list clears previous data)
      await DatabaseService.saveViolations(violators);

      print('Offline data saved successfully!');
    } catch (e) {
      print('Error saving offline data: $e');
      throw Exception(
          'Lokal bazaya yazılarkən xəta baş verdi: ${e.toString()}');
    }
  }

  /// Called by login screen after the download overlay shows success.
  /// Fires a server-side log entry — errors are swallowed silently.
  Future<void> reportDownloadComplete() async {
    try {
      final examDetails = await _httpService.getExamDetailsFromStorage();
      final slotKey = examDetails?.slotKey;
      if (examDetails == null || slotKey == null || slotKey.isEmpty) return;
      final version = await getAppVersion();
      await _httpService.reportDownloadComplete(
        buildingCode: examDetails.buildingCode ?? '0',
        slotKey: slotKey,
        participantCount: _participantCount,
        supervisorCount: _supervisorCount,
        appVersion: version,
      );
    } catch (_) {}
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

  /// Message for a 400 response caused by an invalid/rejected `X-Exam-Slot`
  /// header (see API_slots.md) — prefers the server's own text.
  String _slotErrorMessage(DioException e) {
    final data = e.response?.data;
    final serverMessage = data is Map ? data['message'] as String? : null;
    return (serverMessage != null && serverMessage.isNotEmpty)
        ? serverMessage
        : 'Seçilmiş slot üçün məlumat tapılmadı və ya slot düzgün deyil.';
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
