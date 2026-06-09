import 'package:package_info_plus/package_info_plus.dart';

/// Returns the current app version string (e.g. "9.0.4") from build metadata.
/// Falls back to "0.0.0" if unavailable.
Future<String> getAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return '0.0.0';
  }
}

/// Compares two version strings like "9.0.4" and "9.1.0".
/// Returns true if [current] is lower than [minimum].
bool isVersionOutdated(String current, String minimum) {
  final c = _parseParts(current);
  final m = _parseParts(minimum);
  for (var i = 0; i < m.length; i++) {
    final cv = i < c.length ? c[i] : 0;
    final mv = m[i];
    if (cv < mv) return true;
    if (cv > mv) return false;
  }
  return false;
}

List<int> _parseParts(String version) {
  return version
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^\d]'), '')) ?? 0)
      .toList();
}
