/// Константы версий приложения
class AppVersion {
  AppVersion._();

  /// Версия приложения
  static const String version = '7.0.2';

  /// Build номер
  static const String buildNumber = '1';

  /// Полная версия с build номером
  static String get fullVersion => '$version+$buildNumber';

  /// Название приложения
  static const String appName = 'DIM Buraxılış';
}
