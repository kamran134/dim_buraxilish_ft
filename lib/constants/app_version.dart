import 'dart:io';

/// Константы версий приложения
class AppVersion {
  AppVersion._();

  /// Версия приложения.
  ///
  /// Единый источник правды — `pubspec.yaml` (через PackageInfo). Заполняется
  /// один раз при старте в `main()` (см. `AppVersion.version = await getAppVersion()`),
  /// поэтому в UI всегда совпадает с версией, которую приложение отправляет на
  /// сервер и проверяет при обновлении. Вручную здесь НЕ править.
  static String version = '0.0.0';

  /// Название приложения
  static const String appName = 'DIM Buraxılış';

  // Apple ID of the App Store Connect record for az.dim.buraxilish.
  static const String _appStoreId = '6817806719';

  /// Store page opened by the forced-update dialog.
  static String get storeUrl => Platform.isIOS
      ? 'https://apps.apple.com/app/id$_appStoreId'
      : 'https://play.google.com/store/apps/details?id=com.dim.dim_buraxilish';
}
