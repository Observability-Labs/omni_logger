## [1.0.0] - 2026-05-10

### 🎉 Initial Release

#### Added
- **Core Logging System**
  - `MyLogger` abstract interface with comprehensive logging capabilities
  - `MyLoggerCore` implementation with multi-output support
  - `MyLogConfig` configuration class with auto-detection of debug/profile/release modes

- **Isolate-Aware Logging** 
  - Automatic isolate detection and context-aware configuration
  - Specialized factory constructors for different isolate types:
    - `MyLogger.autoDatabase()` - Optimized for database isolates (Drift, etc.)
    - `MyLogger.autoBackground()` - Minimal logging for background tasks
    - `MyLogger.autoNetwork()` - Network isolate-specific configuration
  - Isolate information helpers and formatting utilities

- **File Logging Features**
  - Automatic log file rotation based on size limits
  - Configurable file retention (by count and age)
  - Optional log file compression
  - Platform-aware file logging (disabled automatically on web)
  - Crash and performance logging outputs

- **Smart Configuration**
  - Auto-configuration based on Flutter build modes:
    - **Debug Mode**: Full logging (debug level), file + console output
    - **Profile Mode**: Structured logging for performance analysis
    - **Release Mode**: Error-only logging, minimal file retention
  - Runtime configuration updates for log levels and file logging
  - Comprehensive logging statistics and health monitoring

- **AppLog Static Interface**
  - Simple setup with `AppLog.setup()` 
  - Direct logging with `AppLog.log('ClassName').level('message')` pattern
  - Specialized isolate setup methods:
    - `AppLog.setupForDatabaseIsolate()`
    - `AppLog.setupForBackgroundIsolate()`
  - Memory leak prevention with automatic cleanup
  - GetIt integration for dependency injection

- **Multiple Output Support**
  - Console output for development
  - File output with rotation and compression
  - Specialized crash logging files
  - Performance metrics logging
  - JSON and production-friendly formatters

- **Developer Experience Features**
  - Automatic fallback to console-only logging on setup failures
  - Comprehensive error handling and recovery mechanisms
  - Debug utilities for isolate information and logging statistics
  - Memory-safe logger tracking with weak references

#### Technical Details
- **Platforms**: Android, iOS, Web (console only), Desktop
- **Dependencies**: Built on top of the `logger` package with custom outputs
- **Architecture**: Abstract interface pattern for extensibility
- **Memory Management**: Automatic cleanup with periodic weak reference collection
- **File System**: Intelligent file I/O with async operations and error recovery

#### Usage Examples
```dart
// Basic setup
AppLog.setup();
AppLog.log('MyApp').i('Application started');

// Database isolate setup
AppLog.setupForDatabaseIsolate(isolateName: 'drift_db');
AppLog.log('DatabaseService').d('Query executed successfully');

// Background isolate setup  
AppLog.setupForBackgroundIsolate(isolateName: 'sync_worker');
AppLog.log('SyncService').w('Sync operation took longer than expected');
```

### 📋 Known Limitations
- File logging is not supported on web platform (by design)
- Log file compression requires additional disk I/O operations
- Initial file output creation may have slight startup delay

### 🔧 Configuration Notes
- Default log retention: 7 days (debug), 3 days (release)
- Default file size limit: 10MB (debug), 2MB (release) 
- Console logging automatically disabled in release mode

---

**Installation**: Add `omni_logger: ^1.0.0` to your `pubspec.yaml`

**Documentation**: See README.md for comprehensive setup and usage examples

**Platform Support**: ✅ Android, iOS, Desktop | 🌐 Web (console only)