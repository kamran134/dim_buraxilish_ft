import 'dart:async';

import 'package:flutter/material.dart';

/// Periodic refresh for an admin screen that is pushed over the shell.
///
/// The timer runs only while the screen is really visible: it stops when an
/// opaque route is pushed over the screen (its tickers are disabled) or the
/// app goes to the background, and starts again — with an immediate refresh —
/// when the screen is uncovered. Call [startAutoRefresh] from `initState`
/// after the first load was started.
mixin AdminAutoRefresh<T extends StatefulWidget> on State<T> {
  /// How often [onAutoRefresh] runs while the screen is visible.
  Duration get autoRefreshInterval => const Duration(seconds: 30);

  /// Reloads the data; must not show a full-screen spinner.
  Future<void> onAutoRefresh();

  Timer? _refreshTimer;
  AppLifecycleListener? _lifecycle;
  bool _covered = false;
  bool _backgrounded = false;
  bool _paused = false;
  bool _started = false;

  bool get autoRefreshRunning => _refreshTimer != null;

  void startAutoRefresh() {
    _started = true;
    _lifecycle = AppLifecycleListener(onStateChange: (state) {
      _backgrounded = state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached;
      _sync();
    });
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _covered = !TickerMode.of(context);
    if (_started) _sync();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  void _sync() {
    final active = mounted && !_covered && !_backgrounded;
    if (!active) {
      if (_refreshTimer != null) _paused = true;
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }
    if (_refreshTimer != null) return;
    _refreshTimer = Timer.periodic(autoRefreshInterval, (_) => onAutoRefresh());
    if (_paused) {
      _paused = false;
      onAutoRefresh();
    }
  }
}
