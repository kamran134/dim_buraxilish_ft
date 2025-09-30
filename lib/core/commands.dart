import '../models/participant_models.dart';
import '../repositories/participant_repository.dart';

/// Command pattern for encapsulating requests as objects
/// Allows parameterizing clients with different requests, queue operations, etc.
abstract class Command<T> {
  Future<T> execute();
  String get description;
}

/// Command for scanning a participant
class ScanParticipantCommand implements Command<ParticipantResponse> {
  final ParticipantRepository _repository;
  final String jobNo;
  final String building;
  final String examDate;

  ScanParticipantCommand(
    this._repository, {
    required this.jobNo,
    required this.building,
    required this.examDate,
  });

  @override
  Future<ParticipantResponse> execute() async {
    return await _repository.scanParticipant(
      jobNo: jobNo,
      building: building,
      examDate: examDate,
    );
  }

  @override
  String get description => 'Scan participant with job number: $jobNo';
}

/// Command for getting participant from offline DB
class GetOfflineParticipantCommand implements Command<Participant?> {
  final ParticipantRepository _repository;
  final int workNumber;

  GetOfflineParticipantCommand(this._repository, {required this.workNumber});

  @override
  Future<Participant?> execute() async {
    return await _repository.getParticipantFromOfflineDB(workNumber);
  }

  @override
  String get description =>
      'Get offline participant with work number: $workNumber';
}

/// Command for registering participant offline
class RegisterOfflineParticipantCommand implements Command<void> {
  final ParticipantRepository _repository;
  final int workNumber;

  RegisterOfflineParticipantCommand(this._repository,
      {required this.workNumber});

  @override
  Future<void> execute() async {
    return await _repository.registerParticipantOffline(workNumber);
  }

  @override
  String get description =>
      'Register offline participant with work number: $workNumber';
}

/// Command invoker that can execute commands and provide logging/error handling
class CommandInvoker {
  final List<Command> _history = [];

  Future<T> execute<T>(Command<T> command) async {
    try {
      print('Executing command: ${command.description}');
      final result = await command.execute();
      _history.add(command);
      print('Command executed successfully: ${command.description}');
      return result;
    } catch (e) {
      print('Command failed: ${command.description}, Error: $e');
      rethrow;
    }
  }

  List<Command> get history => List.unmodifiable(_history);

  void clearHistory() {
    _history.clear();
  }
}
