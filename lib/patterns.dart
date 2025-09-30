/// Central export file for all design patterns and core functionality
/// This file implements the Facade pattern by providing a unified interface

// Core patterns
export 'core/service_factory.dart';
export 'core/auth_strategy.dart';
export 'core/commands.dart';
export 'core/result.dart';

// Repositories
export 'repositories/auth_repository.dart';
export 'repositories/participant_repository.dart';

// Enhanced services
export 'services/storage_service.dart';

// Enhanced providers
export 'providers/enhanced_participant_provider.dart';

/// Design Patterns Documentation
/// 
/// This Flutter project implements several key design patterns:
/// 
/// 1. **Repository Pattern** (`repositories/`)
///    - Abstracts data access logic
///    - Separates business logic from data sources
///    - Makes testing easier with mockable interfaces
/// 
/// 2. **Factory Pattern** (`core/service_factory.dart`)
///    - Creates service instances with proper dependencies
///    - Implements Singleton pattern for shared resources
///    - Provides dependency injection container
/// 
/// 3. **Command Pattern** (`core/commands.dart`)
///    - Encapsulates requests as objects
///    - Allows parameterizing clients with different requests
///    - Provides operation history and undo functionality
/// 
/// 4. **Strategy Pattern** (`core/auth_strategy.dart`)
///    - Defines family of authentication algorithms
///    - Makes them interchangeable at runtime
///    - Enables easy addition of new auth methods
/// 
/// 5. **Result Pattern** (`core/result.dart`)
///    - Better error handling without exceptions
///    - Functional approach to success/failure states
///    - Composable operations with map/flatMap
/// 
/// 6. **Observer Pattern** (Provider package)
///    - Already used for state management
///    - Notifies widgets of state changes
///    - Implements reactive programming principles
/// 
/// 7. **Facade Pattern** (this file)
///    - Provides unified interface to complex subsystem
///    - Simplifies usage of multiple patterns
///    - Reduces coupling between client code and patterns
/// 
/// Usage Example:
/// ```dart
/// // Using dependency injection
/// final authRepo = DependencyInjection.authRepository;
/// 
/// // Using Result pattern
/// final result = await ResultUtils.tryCatchAsync(() => someAsyncOperation());
/// result.onSuccess((value) => print('Success: $value'))
///       .onFailure((error) => print('Error: $error'));
/// 
/// // Using Command pattern
/// final command = ScanParticipantCommand(repository, jobNo: '123', ...);
/// final result = await commandInvoker.execute(command);
/// ```