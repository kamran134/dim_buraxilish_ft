import '../models/participant_models.dart';
import '../services/http_service.dart';

/// Repository pattern for participant-related operations
/// Encapsulates data access logic and business rules
abstract class ParticipantRepository {
  Future<ParticipantResponse> scanParticipant({
    required String jobNo,
    required String building,
    required String examDate,
  });
  Future<Participant?> getParticipantFromOfflineDB(int workNumber);
  Future<void> registerParticipantOffline(int workNumber);
  Future<List<Participant>> getAllParticipants();
  Future<void> syncParticipants(List<Participant> participants);
}

class ParticipantRepositoryImpl implements ParticipantRepository {
  final HttpService _httpService;

  ParticipantRepositoryImpl({
    HttpService? httpService,
  }) : _httpService = httpService ?? HttpService();

  @override
  Future<ParticipantResponse> scanParticipant({
    required String jobNo,
    required String building,
    required String examDate,
  }) async {
    try {
      return await _httpService.scanParticipant(
        jobNo: jobNo,
        building: building,
        examDate: examDate,
      );
    } catch (e) {
      throw ParticipantException('Failed to scan participant: $e');
    }
  }

  @override
  Future<Participant?> getParticipantFromOfflineDB(int workNumber) async {
    try {
      return await _httpService.getParticipantFromOfflineDB(workNumber);
    } catch (e) {
      throw ParticipantException(
          'Failed to get participant from offline DB: $e');
    }
  }

  @override
  Future<void> registerParticipantOffline(int workNumber) async {
    try {
      await _httpService.registerParticipantOffline(workNumber);
    } catch (e) {
      throw ParticipantException('Failed to register participant offline: $e');
    }
  }

  @override
  Future<List<Participant>> getAllParticipants() async {
    try {
      // This would fetch from local DB or cache
      // Implementation depends on your offline storage strategy
      throw UnimplementedError('Not yet implemented');
    } catch (e) {
      throw ParticipantException('Failed to get all participants: $e');
    }
  }

  @override
  Future<void> syncParticipants(List<Participant> participants) async {
    try {
      // This would sync participants to server
      // Implementation depends on your sync strategy
      throw UnimplementedError('Not yet implemented');
    } catch (e) {
      throw ParticipantException('Failed to sync participants: $e');
    }
  }
}

/// Custom exception for participant-related errors
class ParticipantException implements Exception {
  final String message;

  ParticipantException(this.message);

  @override
  String toString() => 'ParticipantException: $message';
}
