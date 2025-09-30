# Flutter Design Patterns Implementation

## 🎯 Overview

This project demonstrates the implementation of multiple design patterns in Flutter to create a maintainable, scalable, and testable codebase. The application manages exam participant scanning with both online and offline capabilities.

## 🏗️ Architecture Patterns Implemented

### 1. Repository Pattern
**Location:** `lib/repositories/`

Abstracts data access logic and provides a clean API for data operations.

```dart
abstract class ParticipantRepository {
  Future<ParticipantResponse> scanParticipant({...});
  Future<Participant?> getParticipantFromOfflineDB(int workNumber);
}

class ParticipantRepositoryImpl implements ParticipantRepository {
  // Implementation details...
}
```

**Benefits:**
- Separates business logic from data sources
- Makes testing easier with mockable interfaces  
- Allows switching between different data sources
- Centralizes data access logic

### 2. Factory Pattern + Singleton
**Location:** `lib/core/service_factory.dart`

Creates and manages service instances with proper dependency injection.

```dart
class ServiceFactory {
  static ServiceFactory get instance => _instance ??= ServiceFactory._();
  
  HttpService createHttpService() {
    return _httpService ??= HttpService();
  }
}
```

**Benefits:**
- Ensures single instances of services (Singleton)
- Provides clean dependency injection
- Easy to mock for testing
- Centralized instance management

### 3. Command Pattern
**Location:** `lib/core/commands.dart`

Encapsulates requests as objects, allowing for parameterization and operation history.

```dart
abstract class Command<T> {
  Future<T> execute();
  String get description;
}

class ScanParticipantCommand implements Command<ParticipantResponse> {
  @override
  Future<ParticipantResponse> execute() async {
    return await _repository.scanParticipant(...);
  }
}
```

**Benefits:**
- Encapsulates operations as objects
- Provides operation history and logging
- Enables undo/redo functionality
- Parameterizes clients with different requests

### 4. Strategy Pattern
**Location:** `lib/core/auth_strategy.dart`

Defines a family of authentication algorithms and makes them interchangeable.

```dart
abstract class AuthStrategy {
  Future<LoginResponse> authenticate(LoginModel credentials);
}

class JwtAuthStrategy implements AuthStrategy {
  @override
  Future<LoginResponse> authenticate(LoginModel credentials) async {
    // JWT implementation
  }
}
```

**Benefits:**
- Easy to add new authentication methods
- Runtime strategy switching
- Follows Open/Closed Principle
- Clean separation of authentication logic

### 5. Result Pattern
**Location:** `lib/core/result.dart`

Better error handling without exceptions using functional programming concepts.

```dart
abstract class Result<T> {
  bool get isSuccess;
  bool get isFailure;
  Result<U> map<U>(U Function(T) mapper);
  Result<T> onSuccess(void Function(T) action);
}
```

**Benefits:**
- No hidden exceptions
- Composable error handling
- Functional programming approach
- Clear success/failure states

### 6. Observer Pattern
**Implementation:** Flutter Provider package

Already implemented for reactive state management.

**Benefits:**
- Automatic UI updates on state changes
- Decoupled component communication
- Reactive programming principles

### 7. Facade Pattern
**Location:** `lib/patterns.dart`

Provides a unified interface to the complex subsystem of design patterns.

```dart
export 'core/service_factory.dart';
export 'repositories/auth_repository.dart';
// ... other exports
```

**Benefits:**
- Simplifies complex subsystem usage
- Reduces coupling between client code
- Single entry point for patterns

## 📁 Project Structure

```
lib/
├── core/                    # Design patterns core
│   ├── service_factory.dart    # Factory + Singleton + DI
│   ├── auth_strategy.dart      # Strategy pattern
│   ├── commands.dart           # Command pattern
│   └── result.dart             # Result pattern
├── repositories/            # Repository pattern
│   ├── auth_repository.dart
│   └── participant_repository.dart
├── services/               # Service layer
│   ├── http_service.dart      # HTTP operations
│   └── storage_service.dart   # Local storage
├── providers/              # State management
│   ├── enhanced_participant_provider.dart  # Using patterns
│   └── participant_provider.dart          # Original
├── models/                 # Data models
├── screens/               # UI screens
├── widgets/               # Reusable widgets
└── patterns.dart          # Facade export
```

## 🚀 Usage Examples

### Dependency Injection
```dart
// Get repositories using Factory pattern
final authRepo = DependencyInjection.authRepository;
final participantRepo = DependencyInjection.participantRepository;
```

### Result Pattern
```dart
final result = await ResultUtils.tryCatchAsync(() async {
  return await someRiskyOperation();
});

result
  .onSuccess((value) => print('Success: $value'))
  .onFailure((error) => handleError(error));
```

### Command Pattern
```dart
final command = ScanParticipantCommand(
  repository,
  jobNo: '123456',
  building: '1099',
  examDate: '2025-09-30',
);

final result = await commandInvoker.execute(command);
```

### Strategy Pattern
```dart
final authContext = AuthContext(JwtAuthStrategy());
final result = await authContext.authenticate(credentials);

// Switch strategy at runtime
authContext.setStrategy(BiometricAuthStrategy());
```

## 🧪 Testing Benefits

The implemented patterns make testing significantly easier:

```dart
// Mock repositories for testing
class MockParticipantRepository implements ParticipantRepository {
  @override
  Future<ParticipantResponse> scanParticipant({...}) async {
    return ParticipantResponse.success(...);
  }
}

// Test with mocked dependencies
final provider = EnhancedParticipantProvider();
// Inject mock repository...
```

## 🔄 Migration Path

The project maintains backward compatibility:

1. **Original Provider:** `participant_provider.dart` (legacy)
2. **Enhanced Provider:** `enhanced_participant_provider.dart` (using patterns)

You can gradually migrate by switching providers in your widget tree.

## 📈 Benefits Achieved

1. **Maintainability:** Clear separation of concerns
2. **Testability:** Easy mocking and unit testing  
3. **Scalability:** Easy to add new features
4. **Flexibility:** Runtime behavior changes
5. **Code Quality:** Following SOLID principles
6. **Error Handling:** Robust Result pattern implementation

## 🛠️ Next Steps

Potential future enhancements:
- Add Decorator pattern for HTTP caching
- Implement Chain of Responsibility for validation
- Add Builder pattern for complex object creation
- Implement State pattern for complex state machines

## 📚 Resources

- [Design Patterns: Elements of Reusable Object-Oriented Software](https://en.wikipedia.org/wiki/Design_Patterns)
- [Flutter Architecture Samples](https://github.com/brianegan/flutter_architecture_samples)
- [Clean Architecture in Flutter](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)