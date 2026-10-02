/// Outcome of a `GET /auth/session` or `POST /devicetokens/heartbeat` call.
enum SessionCheckOutcome {
  /// Server reachable, session is valid.
  active,

  /// Server reachable, this device was deactivated by an administrator.
  revoked,

  /// Server answered 401: the session is invalid (or no token was sent).
  unauthorized,

  /// Network error, timeout, 5xx or any other non-conclusive answer. Callers
  /// must treat this as "offline" and keep working as before.
  unreachable,
}

class SessionCheckResult {
  final SessionCheckOutcome outcome;
  final String? message;

  const SessionCheckResult(this.outcome, {this.message});

  bool get isRevoked => outcome == SessionCheckOutcome.revoked;
  bool get isUnauthorized => outcome == SessionCheckOutcome.unauthorized;
  bool get isUnreachable => outcome == SessionCheckOutcome.unreachable;
}
