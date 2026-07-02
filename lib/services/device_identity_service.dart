import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stable per-install device identity, used so the backend can tell apart
/// multiple physical devices registered for the same exam building.
class DeviceIdentityService {
  static final DeviceIdentityService instance = DeviceIdentityService._();
  DeviceIdentityService._();

  static const _deviceIdKey = 'device_id';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _deviceId;
  String? _deviceName;

  /// Generated once and persisted for the lifetime of the app install.
  Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    var id = await _secureStorage.read(key: _deviceIdKey);
    if (id == null || id.isEmpty) {
      id = _generateId();
      await _secureStorage.write(key: _deviceIdKey, value: id);
    }
    _deviceId = id;
    return id;
  }

  /// Human-readable label for admin screens, e.g. "Samsung SM-T510".
  /// Best-effort only — never blocks registration if unavailable.
  Future<String?> getDeviceName() async {
    if (_deviceName != null) return _deviceName;
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        _deviceName = '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        _deviceName = info.utsname.machine;
      }
    } catch (_) {
      // Ignore — device name is informational, not required.
    }
    return _deviceName;
  }

  String _generateId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
