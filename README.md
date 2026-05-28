# 🚀 Omni Logger

**Production-ready logging for Flutter with auto-configuration and file management.**

*Built on the trusted [logger](https://pub.dev/packages/logger) package with production-ready enhancements and intelligent auto-configuration.*

---

## ⚡ Quick Start

### 1. Add Dependency

```yaml
dependencies:
  omni_logger: ^2.0.0
```

### 2. Setup & Use

```dart
import 'package:omni_logger/omni_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppLog.setup();
  } catch (e) {
    debugPrint('AppLog setup failed: $e');
  }
  runApp(const MyApp());
}

// Use anywhere in your app
AppLog.log('Auth').i('User login successful');
AppLog.log('Payment').e('Payment failed');
AppLog.log('Database').d('Query executed');
```

---

## Table of Contents

- [Features](#-features)
- [Smart Auto-Configuration](#-smart-auto-configuration)
- [Logging Levels](#-logging-levels)
- [Isolate Support](#-isolate-support)
- [Platform Support](#-platform-support)

---

## ✨ Features

| Feature | Detail |
|---------|--------|
| **Zero-config setup** | `AppLog.setup()` — auto-detects debug/profile/release |
| **File management** | Auto rotation, compression, and cleanup |
| **Build optimization** | Different log levels and retention per build mode |
| **Persistent logs** | Survives app restarts for production debugging |
| **Isolate-aware** | Specialized setup for database and background isolates |
| **Cross-platform paths** | `path_provider` for reliable, persistent storage on all platforms |
| **Safe fallbacks** | Three-layer fallback ensures logging never crashes your app |

---

## 🔧 Smart Auto-Configuration

Omni Logger automatically optimizes based on your Flutter build mode:

| Build Mode | Log Level | Files | Size Each | Retention | Console |
|------------|-----------|-------|-----------|-----------|---------|
| **Debug** | DEBUG | 3 files | 5MB | 3 days | ✅ |
| **Profile** | WARNING | 2 files | 3MB | 2 days | ✅ |
| **Release** | ERROR | 1 file | 1MB | 1 day | ❌ |

---

## 📊 Logging Levels

```dart
AppLog.log('ClassName').t('Trace message');   // 🔍 Trace
AppLog.log('ClassName').d('Debug message');   // 🐛 Debug
AppLog.log('ClassName').i('Info message');    // ℹ️  Info
AppLog.log('ClassName').w('Warning message'); // ⚠️  Warning
AppLog.log('ClassName').e('Error message');   // ❌ Error
AppLog.log('ClassName').f('Fatal message');   // 💀 Fatal
```

---

## 🔄 Isolate Support

```dart
// Database isolate (Drift, etc.)
try {
  await AppLog.setupForDatabaseIsolate(isolateName: 'drift_db');
} catch (e) {
  debugPrint('AppLog database isolate setup failed: $e');
}
AppLog.log('Database').d('Query executed successfully');

// Background isolate
try {
  await AppLog.setupForBackgroundIsolate(isolateName: 'sync_worker');
} catch (e) {
  debugPrint('AppLog background isolate setup failed: $e');
}
AppLog.log('SyncService').w('Sync took longer than expected');
```

---

## 📱 Platform Support

| Platform | Console | File Logging |
|----------|---------|--------------|
| Android  | ✅      | ✅           |
| iOS      | ✅      | ✅           |
| macOS    | ✅      | ✅           |
| Windows  | ✅      | ✅           |
| Linux    | ✅      | ✅           |
| Web      | ✅      | ❌ (by design) |

---

## Contributing

Contributions are welcome! Please submit pull requests to our [repository](https://github.com/Observability-Labs/omni_logger).

## License

MIT License — see [LICENSE](LICENSE) for details.

---

**Platform Support**: ✅ Android, iOS, macOS, Windows, Linux | 🌐 Web (console only)

Built with ❤️ for the Flutter community