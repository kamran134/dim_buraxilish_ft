import 'dart:async';
import 'package:flutter/foundation.dart';

/// Глобальный сервис для уведомления об обновлении статистики
/// Используется для обновления дашборда после сканирования мониторов/супервайзеров
class StatisticsEventBus {
  static final StatisticsEventBus _instance = StatisticsEventBus._internal();
  factory StatisticsEventBus() => _instance;
  StatisticsEventBus._internal();

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  /// Стрим для подписки на события обновления статистики
  Stream<String> get onStatisticsUpdate => _controller.stream;

  /// Уведомить всех слушателей об обновлении статистики
  void notifyStatisticsUpdate(String source) {
    if (kDebugMode) {
      print('📊 [EVENT_BUS] Уведомление об обновлении статистики от: $source');
    }
    if (!_controller.isClosed) {
      _controller.add(source);
    }
  }

  /// Закрыть стрим (обычно не нужно, так как синглтон)
  void dispose() {
    _controller.close();
  }
}
