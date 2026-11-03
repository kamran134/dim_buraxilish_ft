import 'package:flutter/material.dart';

/// Wraps a live camera view and calls [onDeactivate] (once) when the camera
/// must stop: [active] turns false (another shell tab was selected), a route
/// is pushed over the page, or the app goes to the background. It never
/// restarts anything — the user starts the scan again.
///
/// `inactive` is deliberately ignored: the camera permission dialog and
/// system overlays raise it while the scanner is still wanted.
class ScanActivityGuard extends StatefulWidget {
  final bool active;
  final VoidCallback onDeactivate;
  final Widget child;

  const ScanActivityGuard({
    super.key,
    this.active = true,
    required this.onDeactivate,
    required this.child,
  });

  @override
  State<ScanActivityGuard> createState() => _ScanActivityGuardState();
}

class _ScanActivityGuardState extends State<ScanActivityGuard>
    with WidgetsBindingObserver {
  bool _covered = false;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // An opaque page on top disables the tickers of the routes below it;
    // translucent dialogs do not.
    _covered = !TickerMode.of(context);
    _checkActive();
  }

  @override
  void didUpdateWidget(ScanActivityGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkActive();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _deactivate();
    }
  }

  void _checkActive() {
    if (!widget.active || _covered) _deactivate();
  }

  // Deferred: the parent may be mid-build when the flag flips, and the
  // callback usually notifies a provider.
  void _deactivate() {
    if (_notified) return;
    _notified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDeactivate();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
