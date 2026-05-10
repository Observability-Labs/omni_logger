## [1.0.2] - 2026-05-11

### Fixed
- Downgraded `device_info_plus` to `^10.1.0` to resolve `win32` version conflict with `flutter_secure_storage_windows`

## [1.0.1] - 2026-05-11

### Changed
- Added repository link to pubspec.yaml

## [1.0.0] - 2026-05-11

### 🎉 Initial Release

#### Added
- **Core Logging System**
  - `OmniLogger` interface with comprehensive logging capabilities
  - `OmniLoggerClient` implementation with multi-output support
  - `OmniLogConfig` configuration class with auto-detection of debug/profile/release modes

- **Isolate-Aware Logging**
  - Automatic isolate detection and context-aware configuration
  - Specialized setup methods for different isolate types:
    - `AppLog.setupForDatabaseIsolate()` - Optimized for database isolates (Drift, etc.)
    - `AppLog.setupForBackgroundIsolate()` - Minimal logging for background tasks
  - Isolate information helpers and formatting utilities

- **File Logging Features**
  - Automatic log file rotation based on size limits
  - Configurable file retention (by count and age)
  - Optional log file compression
  - Platform-aware file logging (disabled automatically on web)

- **Smart Configuration**
  - Auto-configuration based on Flutter build modes:
    - **Debug Mode**: Full logging (debug level), file + console output
    - **Profile Mode**: Structured logging for performance analysis
    - **Release Mode**: Error-only logging, minimal file retention
  - Runtime configuration updates for log levels and file logging
  - Comprehensive logging statistics and health monitoring

- **AppLog Static Interface**
  - Simple setup with `AppLog.setup()`
  - Direct logging with `AppLog.log('ClassName').i('message')` pattern
  - Specialized isolate setup:
    - `AppLog.setupForDatabaseIsolate()`
    - `AppLog.setupForBackgroundIsolate()`
  - Memory leak prevention with automatic cleanup

- **Multiple Output Support**
  - Console output for development
  - File output with rotation and compression
  - JSON and production-friendly formatters

- **Developer Experience**
  - Automatic fallback to console-only logging on setup failures
  - Comprehensive error handling and recovery mechanisms
  - Debug utilities for isolate information and logging statistics
  - Memory-safe logger tracking with weak references

#### Usage Examples
```dart
// Basic setup
AppLog.setup();
AppLog.log('MyApp').i('Application started');

// Database isolate
AppLog.setupForDatabaseIsolate(isolateName: 'drift_db');
AppLog.log('DatabaseService').d('Query executed successfully');

// Background isolate
AppLog.setupForBackgroundIsolate(isolateName: 'sync_worker');
AppLog.log('SyncService').w('Sync operation took longer than expected');
```

### 📋 Known Limitations
- File logging is not supported on web platform (by design)
- Log file compression requires additional disk I/O operations
- Initial file output creation may have slight startup delay

### 🔧 Configuration Notes
- Default log retention: 3 days (debug), 1 day (release)
- Default file size limit: 5MB (debug), 1MB (release)
- Console logging automatically disabled in release mode

---

**Platform Support**: ✅ Android, iOS, macOS, Windows, Linux | 🌐 Web (console only)