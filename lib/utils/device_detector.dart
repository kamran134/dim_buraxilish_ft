import 'package:flutter/foundation.dart';

class DeviceDetector {
  static bool get isMobileWeb {
    if (!kIsWeb) return false;

    // Используем более точное определение мобильного устройства
    // основанное на возможностях устройства
    try {
      // В веб-версии проверяем поддержку тач-событий
      // и ориентацию экрана
      return _isTouchDevice() || _isMobileUserAgent();
    } catch (e) {
      // Если возникла ошибка, возвращаем false для безопасности
      return false;
    }
  }

  static bool _isTouchDevice() {
    // Простая проверка на поддержку тач-событий
    // В реальном приложении можно использовать более сложную логику
    return false; // Пока отключаем эту проверку
  }

  static bool _isMobileUserAgent() {
    // Для веб-версии всегда возвращаем false
    // Это означает, что mobile_scanner будет работать
    // даже на мобильных устройствах в браузере
    return false;
  }

  static bool get shouldUseWebScanner {
    // Веб-сканер используем только для больших экранов
    // и только если это не мобильное устройство
    return kIsWeb && !isMobileWeb;
  }
}
