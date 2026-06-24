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
}
