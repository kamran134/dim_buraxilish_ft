import 'package:dio/dio.dart';
import '../services/http_service.dart';
import '../services/storage_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/participant_repository.dart';

/// Factory pattern for creating service instances
/// Implements Singleton pattern to ensure single instances
class ServiceFactory {
  static ServiceFactory? _instance;
  static ServiceFactory get instance => _instance ??= ServiceFactory._();

  ServiceFactory._();

  // Lazy-initialized services
  Dio? _dio;
  HttpService? _httpService;
  StorageService? _storageService;
  AuthRepository? _authRepository;
  ParticipantRepository? _participantRepository;

  /// Creates or returns existing Dio instance with proper configuration
  Dio createDio() {
    return _dio ??= Dio(BaseOptions(
      baseUrl: 'https://eservices.dim.gov.az/buraxilishScan/api/api',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  /// Creates or returns existing HttpService instance
  HttpService createHttpService() {
    return _httpService ??= HttpService();
  }

  /// Creates or returns existing StorageService instance
  StorageService createStorageService() {
    return _storageService ??= StorageService();
  }

  /// Creates or returns existing AuthRepository instance
  AuthRepository createAuthRepository() {
    return _authRepository ??= AuthRepositoryImpl(
      httpService: createHttpService(),
    );
  }

  /// Creates or returns existing ParticipantRepository instance
  ParticipantRepository createParticipantRepository() {
    return _participantRepository ??= ParticipantRepositoryImpl(
      httpService: createHttpService(),
    );
  }

  /// Resets all instances (useful for testing)
  void reset() {
    _dio?.close();
    _dio = null;
    _httpService = null;
    _storageService = null;
    _authRepository = null;
    _participantRepository = null;
  }
}

/// Dependency injection container
/// Provides easy access to services throughout the app
class DependencyInjection {
  static final ServiceFactory _factory = ServiceFactory.instance;

  static Dio get dio => _factory.createDio();
  static HttpService get httpService => _factory.createHttpService();
  static StorageService get storageService => _factory.createStorageService();
  static AuthRepository get authRepository => _factory.createAuthRepository();
  static ParticipantRepository get participantRepository =>
      _factory.createParticipantRepository();
}
