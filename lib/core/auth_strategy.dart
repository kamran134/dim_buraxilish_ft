import '../models/auth_models.dart';

/// Strategy pattern for different authentication methods
/// Allows easy switching between authentication strategies
abstract class AuthStrategy {
  Future<LoginResponse> authenticate(LoginModel credentials);
  String get strategyName;
}

/// JWT-based authentication strategy
class JwtAuthStrategy implements AuthStrategy {
  @override
  String get strategyName => 'JWT';

  @override
  Future<LoginResponse> authenticate(LoginModel credentials) async {
    // Implementation would be moved here from HttpService
    throw UnimplementedError('JWT authentication not yet implemented');
  }
}

/// OAuth authentication strategy (for future use)
class OAuthStrategy implements AuthStrategy {
  @override
  String get strategyName => 'OAuth';

  @override
  Future<LoginResponse> authenticate(LoginModel credentials) async {
    throw UnimplementedError('OAuth authentication not yet implemented');
  }
}

/// Biometric authentication strategy (for future use)
class BiometricAuthStrategy implements AuthStrategy {
  @override
  String get strategyName => 'Biometric';

  @override
  Future<LoginResponse> authenticate(LoginModel credentials) async {
    throw UnimplementedError('Biometric authentication not yet implemented');
  }
}

/// Context class that uses authentication strategies
class AuthContext {
  AuthStrategy _strategy;

  AuthContext(this._strategy);

  void setStrategy(AuthStrategy strategy) {
    _strategy = strategy;
  }

  Future<LoginResponse> authenticate(LoginModel credentials) async {
    return await _strategy.authenticate(credentials);
  }

  String get currentStrategyName => _strategy.strategyName;
}

/// Factory for creating authentication strategies
class AuthStrategyFactory {
  static AuthStrategy createStrategy(AuthType type) {
    switch (type) {
      case AuthType.jwt:
        return JwtAuthStrategy();
      case AuthType.oauth:
        return OAuthStrategy();
      case AuthType.biometric:
        return BiometricAuthStrategy();
      default:
        return JwtAuthStrategy(); // Default to JWT
    }
  }
}

/// Enum for different authentication types
enum AuthType {
  jwt,
  oauth,
  biometric,
}
