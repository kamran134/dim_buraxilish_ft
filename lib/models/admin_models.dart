/// DTOs of the admin-only endpoints: device status (`admin/*`), emergency
/// messages (`emergencymessages/*`) and the profile (`auth/me`).
library;

DateTime? _date(dynamic value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

int? _int(dynamic value) => value is num ? value.toInt() : null;

String? _string(dynamic value) => value?.toString();

/// A device that is silent for longer than this is shown as offline / state
/// unknown (same window as the web admin).
const Duration deviceOnlineWindow = Duration(minutes: 10);

/// One registered device with its last database download and session state
/// (`admin/devicelogins`). The pending counts, [lastSeenAt] and [slotKey]
/// come from the app heartbeat and are null on older app versions.
class DeviceLogin {
  final String buildingCode;
  final String? buildingName;
  final String? deviceId;
  final String? deviceName;
  final String? examDateRaw;
  final DateTime? downloadedAt;
  final int? participantCount;
  final int? supervisorCount;
  final String? appVersion;
  final DateTime? lastSeenAt;
  final int? pendingParticipants;
  final int? pendingSupervisors;
  final bool isRevoked;
  final DateTime? revokedAt;

  const DeviceLogin({
    required this.buildingCode,
    this.buildingName,
    this.deviceId,
    this.deviceName,
    this.examDateRaw,
    this.downloadedAt,
    this.participantCount,
    this.supervisorCount,
    this.appVersion,
    this.lastSeenAt,
    this.pendingParticipants,
    this.pendingSupervisors,
    this.isRevoked = false,
    this.revokedAt,
  });

  factory DeviceLogin.fromJson(Map<String, dynamic> json) => DeviceLogin(
        buildingCode: _string(json['buildingCode']) ?? '',
        buildingName: _string(json['buildingName']),
        deviceId: _string(json['deviceId']),
        deviceName: _string(json['deviceName']),
        examDateRaw: _string(json['examDateRaw']),
        downloadedAt: _date(json['downloadedAt']),
        participantCount: _int(json['participantCount']),
        supervisorCount: _int(json['supervisorCount']),
        appVersion: _string(json['appVersion']),
        lastSeenAt: _date(json['lastSeenAt']),
        pendingParticipants: _int(json['pendingParticipants']),
        pendingSupervisors: _int(json['pendingSupervisors']),
        isRevoked: json['isRevoked'] == true,
        revokedAt: _date(json['revokedAt']),
      );

  bool isRecentlySeen(DateTime now) =>
      lastSeenAt != null && now.difference(lastSeenAt!) <= deviceOnlineWindow;

  /// Unsent records the phone reported in its last heartbeat; null when it
  /// never reported.
  int? get pendingTotal {
    if (pendingParticipants == null && pendingSupervisors == null) return null;
    return (pendingParticipants ?? 0) + (pendingSupervisors ?? 0);
  }

  bool get hasPending => (pendingTotal ?? 0) > 0;
}

/// Offline-database download state of one building (`admin/downloadstatus`).
enum BuildingDownloadState { downloaded, notDownloaded, noDevice }

class BuildingDownloadStatus {
  final String buildingCode;
  final String? buildingName;
  final DateTime? downloadedAt;
  final int? participantCount;
  final int? supervisorCount;
  final BuildingDownloadState state;

  const BuildingDownloadStatus({
    required this.buildingCode,
    this.buildingName,
    this.downloadedAt,
    this.participantCount,
    this.supervisorCount,
    required this.state,
  });

  factory BuildingDownloadStatus.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final state = status == 'downloaded' || json['hasDownloaded'] == true
        ? BuildingDownloadState.downloaded
        : status == 'no_device' || json['hasDevice'] == false
            ? BuildingDownloadState.noDevice
            : BuildingDownloadState.notDownloaded;
    return BuildingDownloadStatus(
      buildingCode: _string(json['buildingCode']) ?? '',
      buildingName: _string(json['buildingName']),
      downloadedAt: _date(json['downloadedAt']),
      participantCount: _int(json['participantCount']),
      supervisorCount: _int(json['supervisorCount']),
      state: state,
    );
  }
}

class DownloadStatusSummary {
  final int total;
  final int downloaded;
  final int notDownloaded;
  final int noDevice;

  const DownloadStatusSummary({
    this.total = 0,
    this.downloaded = 0,
    this.notDownloaded = 0,
    this.noDevice = 0,
  });

  factory DownloadStatusSummary.fromJson(Map<String, dynamic> json) =>
      DownloadStatusSummary(
        total: _int(json['total']) ?? 0,
        downloaded: _int(json['downloaded']) ?? 0,
        notDownloaded: _int(json['notDownloaded']) ?? 0,
        noDevice: _int(json['noDevice']) ?? 0,
      );
}

class DownloadStatusReport {
  final DownloadStatusSummary summary;
  final List<BuildingDownloadStatus> buildings;

  const DownloadStatusReport({required this.summary, required this.buildings});
}

enum RevokeScope { device, building, all }

class RevokeResult {
  final int devices;
  final int devicesWithPending;

  const RevokeResult({required this.devices, required this.devicesWithPending});

  factory RevokeResult.fromJson(Map<String, dynamic> json) => RevokeResult(
        devices: _int(json['devices']) ?? 0,
        devicesWithPending: _int(json['devicesWithPending']) ?? 0,
      );
}

/// Profile of the signed-in user (`auth/me`).
class CurrentUser {
  final String userName;
  final String role;
  final String? buildingCode;
  final String? buildingName;

  const CurrentUser({
    required this.userName,
    required this.role,
    this.buildingCode,
    this.buildingName,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        userName: _string(json['userName']) ?? '',
        role: _string(json['role']) ?? '',
        buildingCode: _string(json['buildingCode']),
        buildingName: _string(json['buildingName']),
      );

  /// Role caption in the app's wording (the role "monitor" is the general
  /// exam supervisor).
  String get roleLabel => switch (role.toLowerCase()) {
        'admin' => 'Administrator',
        'superadmin' => 'Super Administrator',
        'monitor' => 'Ümumi imtahan rəhbəri',
        'moderator' => 'Moderator',
        '' => 'Naməlum rol',
        _ => role,
      };
}

enum EmergencyImportance {
  info(0, 'Məlumat', 'Ümumi elan'),
  warning(1, 'Xəbərdarlıq', 'Diqqət tələb edir'),
  urgent(2, 'Təcili', 'Dərhal icra et');

  final int value;
  final String label;
  final String description;

  const EmergencyImportance(this.value, this.label, this.description);

  static EmergencyImportance fromValue(int? value) =>
      values.firstWhere((e) => e.value == value, orElse: () => info);
}

/// A building that acknowledged an emergency message.
class EmergencyAck {
  final String buildingCode;
  final String buildingName;
  final DateTime? acknowledgedAt;

  const EmergencyAck({
    required this.buildingCode,
    required this.buildingName,
    this.acknowledgedAt,
  });

  factory EmergencyAck.fromJson(Map<String, dynamic> json) => EmergencyAck(
        buildingCode: _string(json['buildingCode']) ?? '',
        buildingName: _string(json['buildingName']) ?? '',
        acknowledgedAt: _date(json['acknowledgedAt']),
      );
}

/// A sent emergency message with its acknowledgements
/// (`emergencymessages/history`).
class EmergencyHistoryItem {
  final int id;
  final String title;
  final String body;
  final EmergencyImportance importance;
  final DateTime? sentAt;
  final bool isForAll;
  final int ackCount;
  final List<EmergencyAck> acks;

  const EmergencyHistoryItem({
    required this.id,
    required this.title,
    required this.body,
    required this.importance,
    this.sentAt,
    required this.isForAll,
    required this.ackCount,
    this.acks = const [],
  });

  factory EmergencyHistoryItem.fromJson(Map<String, dynamic> json) {
    final acks = [
      for (final ack in (json['acks'] as List<dynamic>? ?? const []))
        if (ack is Map) EmergencyAck.fromJson(Map<String, dynamic>.from(ack)),
    ];
    return EmergencyHistoryItem(
      id: _int(json['id']) ?? 0,
      title: _string(json['title']) ?? '',
      body: _string(json['body']) ?? '',
      importance: EmergencyImportance.fromValue(_int(json['importance'])),
      sentAt: _date(json['sentAt']),
      isForAll: (_string(json['targetType']) ?? 'ALL').toUpperCase() != 'SPECIFIC',
      ackCount: _int(json['ackCount']) ?? acks.length,
      acks: acks,
    );
  }
}

/// A building the emergency message can be addressed to.
class EmergencyBuilding {
  final String code;
  final String name;

  const EmergencyBuilding({required this.code, required this.name});
}
