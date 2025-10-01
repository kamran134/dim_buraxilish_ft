import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/http_service.dart';
import '../models/participant_models.dart';
import '../models/supervisor_models.dart';

enum UnsentDataType { participants, supervisors }

class UnsentDataProvider extends ChangeNotifier {
  // State variables
  List<Participant> _registeredParticipants = [];
  List<Supervisor> _registeredSupervisors = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  UnsentDataType _selectedType = UnsentDataType.participants;
  bool _isSyncing = false;
  final HttpService _httpService = HttpService();

  // Getters
  List<Participant> get registeredParticipants => _registeredParticipants;
  List<Supervisor> get registeredSupervisors => _registeredSupervisors;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  UnsentDataType get selectedType => _selectedType;
  bool get isSyncing => _isSyncing;

  bool get hasUnsentData =>
      _registeredParticipants.isNotEmpty || _registeredSupervisors.isNotEmpty;

  int get unsentParticipantsCount => _registeredParticipants.length;
  int get unsentSupervisorsCount => _registeredSupervisors.length;

  // Switch between data types (participants/supervisors)
  void setSelectedType(UnsentDataType type) {
    _selectedType = type;
    notifyListeners();
  }

  // Load unsent data from database
  Future<void> loadUnsentData() async {
    _setLoading(true);
    _clearMessages();

    try {
      // Load registered participants (only offline ones - not synced with server)
      final allParticipants = await DatabaseService.getRegisteredParticipants();
      _registeredParticipants = allParticipants
          .where((p) => p.qeydiyyat != null && p.qeydiyyat!.isNotEmpty)
          .toList();

      // Load registered supervisors (only offline ones - not synced with server)
      final allSupervisors = await DatabaseService.getRegisteredSupervisors();
      _registeredSupervisors =
          allSupervisors.where((s) => s.registerDate.isNotEmpty).toList();

      print('Loaded ${_registeredParticipants.length} unsent participants');
      print('Loaded ${_registeredSupervisors.length} unsent supervisors');
    } catch (e) {
      print('Error loading unsent data: $e');
      _setError('Göndərilməmiş məlumatlar yüklənərkən xəta baş verdi');
    } finally {
      _setLoading(false);
    }
  }

  // Sync all unsent data to server
  Future<void> syncUnsentData() async {
    if (_isSyncing) return; // Prevent multiple sync operations

    _isSyncing = true;
    _setLoading(true);
    _clearMessages();

    try {
      bool hasSuccessfulSync = false;
      List<String> errors = [];
      List<String> successes = [];

      // Sync participants if any
      if (_registeredParticipants.isNotEmpty) {
        print('Syncing ${_registeredParticipants.length} participants...');
        final participantResult =
            await _httpService.syncParticipants(_registeredParticipants);

        if (participantResult.success) {
          hasSuccessfulSync = true;
          successes.add('İştirakçılar: ${_registeredParticipants.length}');

          // Clear synced participants from local database
          await _clearSyncedParticipants();
        } else {
          errors.add('İştirakçılar: ${participantResult.message}');
        }
      }

      // Sync supervisors if any
      if (_registeredSupervisors.isNotEmpty) {
        print('Syncing ${_registeredSupervisors.length} supervisors...');
        final supervisorResult =
            await _httpService.syncSupervisors(_registeredSupervisors);

        if (supervisorResult.success) {
          hasSuccessfulSync = true;
          successes.add('Nəzarətçilər: ${_registeredSupervisors.length}');

          // Clear synced supervisors from local database
          await _clearSyncedSupervisors();
        } else {
          errors.add('Nəzarətçilər: ${supervisorResult.message}');
        }
      }

      // Show results
      if (hasSuccessfulSync) {
        if (errors.isEmpty) {
          _setSuccess(
              'Bütün məlumatlar uğurla sinxronizasiya edildi!\n${successes.join('\n')}');
          // Reload data to show updated state
          await loadUnsentData();
        } else {
          _setSuccess(
              'Bəzi məlumatlar sinxronizasiya edildi:\n${successes.join('\n')}');
          _setError('Xətalı məlumatlar:\n${errors.join('\n')}');
        }
      } else {
        if (errors.isNotEmpty) {
          _setError('Sinxronizasiya uğursuz oldu:\n${errors.join('\n')}');
        } else {
          _setError('Sinxronizasiya ediləcək məlumat tapılmadı');
        }
      }
    } catch (e) {
      print('Error during sync: $e');
      _setError('Sinxronizasiya zamanı gözlənilməz xəta baş verdi');
    } finally {
      _isSyncing = false;
      _setLoading(false);
    }
  }

  // Clear synced participants from local database
  Future<void> _clearSyncedParticipants() async {
    try {
      // For now, clear all registered participants since we synced them all
      // TODO: Implement individual clearing when needed
      await DatabaseService.clearAllRegisteredParticipants();
      _registeredParticipants.clear();
    } catch (e) {
      print('Error clearing synced participants: $e');
    }
  }

  // Clear synced supervisors from local database
  Future<void> _clearSyncedSupervisors() async {
    try {
      // For now, clear all registered supervisors since we synced them all
      // TODO: Implement individual clearing when needed
      await DatabaseService.clearAllRegisteredSupervisors();
      _registeredSupervisors.clear();
    } catch (e) {
      print('Error clearing synced supervisors: $e');
    }
  }

  // Clear all messages
  void clearMessages() {
    _clearMessages();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();

    // Auto clear after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_errorMessage == message) {
        _errorMessage = null;
        notifyListeners();
      }
    });
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();

    // Auto clear after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_successMessage == message) {
        _successMessage = null;
        notifyListeners();
      }
    });
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
