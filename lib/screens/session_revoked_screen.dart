import 'package:flutter/material.dart';
import '../services/session_revoke_service.dart';
import '../services/sync_service.dart';

/// Blocking screen shown when the session was revoked but the phone still has
/// registrations that could not be sent. It cannot be dismissed; the data stays
/// on the phone until it is sent (or until the user logs in again, after which
/// [SyncService.kickstartIfPending] sends it).
class SessionRevokedScreen extends StatefulWidget {
  const SessionRevokedScreen({Key? key}) : super(key: key);

  @override
  State<SessionRevokedScreen> createState() => _SessionRevokedScreenState();
}

class _SessionRevokedScreenState extends State<SessionRevokedScreen> {
  final SessionRevokeService _revoke = SessionRevokeService.instance;
  final SyncService _sync = SyncService.instance;

  bool _busy = false;
  String? _error;
  bool _needsRelogin = false;

  @override
  void initState() {
    super.initState();
    final last = _revoke.lastDrain;
    _error = last?.error;
    _needsRelogin = last?.needsRelogin ?? false;
    // The background sync timer keeps running; if it empties the queue (the
    // connection came back) leave the flow without waiting for a tap.
    _sync.addListener(_onSyncChanged);
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (_sync.pendingTotal == 0 && !_sync.isSyncing && !_busy) {
      _revoke.finishIfDrained();
    }
  }

  Future<void> _retry() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _revoke.retry();
    if (!mounted) return;
    // If the queue is empty the service is already navigating to the login.
    setState(() {
      _busy = false;
      _error = result.error;
      _needsRelogin = result.needsRelogin;
    });
  }

  Future<void> _relogin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Yenidən daxil ol',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Göndərilməmiş ${_sync.pendingTotal} qeyd telefonda qalacaq və '
          'yenidən daxil olduqdan sonra avtomatik göndəriləcək.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Ləğv et'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Davam et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    await _revoke.reloginKeepingQueue();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _revoke.reason == RevokeReason.sessionExpired;
    final serverMessage = _revoke.serverMessage;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AnimatedBuilder(
                  animation: _sync,
                  builder: (context, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.block_rounded,
                          size: 72, color: Colors.orange),
                      const SizedBox(height: 20),
                      Text(
                        expired
                            ? 'Sessiyanın müddəti bitib'
                            : 'Cihaz deaktiv edilib',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        expired
                            ? 'Sessiyanız başa çatıb.'
                            : 'Bu cihaz administrator tərəfindən deaktiv edilib.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15),
                      ),
                      if (!expired &&
                          serverMessage != null &&
                          serverMessage.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          serverMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_sync.pendingParticipants} iştirakçı və '
                              '${_sync.pendingSupervisors} nəzarətçi qeydi '
                              'hələ serverə göndərilməyib.',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Məlumatların itməməsi üçün internetə qoşulun.',
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _needsRelogin
                                    ? Icons.lock_outline
                                    : Icons.wifi_off,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _busy ? null : _retry,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Yenidən göndər',
                                style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _busy ? null : _relogin,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Yenidən daxil ol',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
