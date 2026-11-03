import '../../../models/admin_models.dart';

/// Status filter of the device list.
enum DeviceFilter { all, online, offline, revoked, pending }

/// Sort keys of the device list.
enum DeviceSort { downloadedAt, buildingCode, buildingName, deviceName, pending }

/// Status filter of the building download list.
enum BuildingFilter { all, downloaded, notDownloaded, noDevice }

bool _contains(String? haystack, String needle) =>
    haystack != null && haystack.toLowerCase().contains(needle);

/// Devices matching [query] (building code / name, device name, exam date)
/// and [filter]: the web table search plus the status chips.
List<DeviceLogin> filterDevices(
  List<DeviceLogin> devices, {
  required String query,
  required DeviceFilter filter,
  required DateTime now,
}) {
  final term = query.trim().toLowerCase();
  return [
    for (final device in devices)
      if ((term.isEmpty ||
              _contains(device.buildingCode, term) ||
              _contains(device.buildingName, term) ||
              _contains(device.deviceName, term) ||
              _contains(device.examDateRaw, term)) &&
          switch (filter) {
            DeviceFilter.all => true,
            DeviceFilter.online =>
              !device.isRevoked && device.isRecentlySeen(now),
            DeviceFilter.offline =>
              !device.isRevoked && !device.isRecentlySeen(now),
            DeviceFilter.revoked => device.isRevoked,
            DeviceFilter.pending => device.hasPending,
          })
        device,
  ];
}

int _compareNullable<V extends Comparable<Object>>(V? a, V? b) {
  // Missing values sort first ascending, like the web table.
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

/// Building codes are numbers: compare them as such, text otherwise.
int _compareCodes(String a, String b) {
  final na = int.tryParse(a);
  final nb = int.tryParse(b);
  if (na != null && nb != null) return na.compareTo(nb);
  return a.toLowerCase().compareTo(b.toLowerCase());
}

List<DeviceLogin> sortDevices(
  List<DeviceLogin> devices,
  DeviceSort sort, {
  required bool ascending,
}) {
  int compare(DeviceLogin a, DeviceLogin b) => switch (sort) {
        DeviceSort.downloadedAt =>
          _compareNullable(a.downloadedAt, b.downloadedAt),
        DeviceSort.buildingCode => _compareCodes(a.buildingCode, b.buildingCode),
        DeviceSort.buildingName => _compareNullable(
            a.buildingName?.toLowerCase(),
            b.buildingName?.toLowerCase(),
          ),
        DeviceSort.deviceName => _compareNullable(
            a.deviceName?.toLowerCase(),
            b.deviceName?.toLowerCase(),
          ),
        DeviceSort.pending => _compareNullable(a.pendingTotal, b.pendingTotal),
      };
  final sorted = [...devices]..sort(compare);
  return ascending ? sorted : sorted.reversed.toList();
}

/// Counters of the summary tiles.
class DeviceCounts {
  final int total;
  final int online;
  final int revoked;
  final int withPending;

  const DeviceCounts({
    required this.total,
    required this.online,
    required this.revoked,
    required this.withPending,
  });

  factory DeviceCounts.of(List<DeviceLogin> devices, DateTime now) =>
      DeviceCounts(
        total: devices.length,
        online:
            devices.where((d) => !d.isRevoked && d.isRecentlySeen(now)).length,
        revoked: devices.where((d) => d.isRevoked).length,
        withPending: devices.where((d) => d.hasPending).length,
      );
}

List<BuildingDownloadStatus> filterBuildings(
  List<BuildingDownloadStatus> buildings, {
  required String query,
  required BuildingFilter filter,
}) {
  final term = query.trim().toLowerCase();
  return [
    for (final building in buildings)
      if ((term.isEmpty ||
              _contains(building.buildingCode, term) ||
              _contains(building.buildingName, term)) &&
          switch (filter) {
            BuildingFilter.all => true,
            BuildingFilter.downloaded =>
              building.state == BuildingDownloadState.downloaded,
            BuildingFilter.notDownloaded =>
              building.state == BuildingDownloadState.notDownloaded,
            BuildingFilter.noDevice =>
              building.state == BuildingDownloadState.noDevice,
          })
        building,
  ];
}

/// Text of the revoke confirmation: the [question] plus the same warnings as
/// the web admin about unsent records and devices whose state is unknown.
String revokeConfirmationText({
  required String question,
  required List<DeviceLogin> devices,
  required DateTime now,
}) {
  final active = devices.where((d) => !d.isRevoked).toList();
  final withPending = active.where((d) => d.hasPending).toList();
  final pendingSum =
      withPending.fold<int>(0, (sum, d) => sum + (d.pendingTotal ?? 0));
  final unknown = active
      .where((d) => d.pendingTotal == null || !d.isRecentlySeen(now))
      .toList();

  final lines = [
    question,
    '',
    'Tətbiq açıldıqda istifadəçi giriş səhifəsinə yönləndiriləcək.',
  ];
  if (withPending.isNotEmpty) {
    lines.addAll([
      '',
      '⚠ ${withPending.length} cihazda göndərilməmiş $pendingSum qeyd var. '
          'Cihaz əvvəlcə onları göndərəcək; internet olmasa, qeydlər '
          'telefonda saxlanılacaq və çıxış göndərilənə qədər gözləyəcək.',
    ]);
  }
  if (unknown.isNotEmpty) {
    lines.addAll([
      '',
      '⚠ ${unknown.length} cihazın vəziyyəti naməlumdur (köhnə tətbiq '
          'versiyası və ya 10 dəqiqədən çox əlaqə yoxdur) — onlarda '
          'göndərilməmiş qeyd ola bilər.',
    ]);
  }
  return lines.join('\n');
}
