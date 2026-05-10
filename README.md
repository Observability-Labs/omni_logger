# 🚀 Omni Logger

**Production-ready logging for Flutter with auto-configuration and file management.**

*Built on the trusted [logger](https://pub.dev/packages/logger) package with production-ready enhancements and intelligent auto-configuration.*

---

## ⚡ Quick Start

### 1. Add Dependency

```yaml
dependencies:
  omni_logger: ^1.0.0
```

### 2. Setup & Use

```dart
import 'package:omni_logger/omni_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLog.setup();
  runApp(const MyApp());
}

// Use anywhere in your app
AppLog.log('Auth').i('User login successful');
AppLog.log('Payment').e('Payment failed');
AppLog.log('Database').d('Query executed');
```

---

## Table of Contents

- [Why Omni Logger?](#-why-omni-logger)
- [Smart Auto-Configuration](#-smart-auto-configuration)
- [Logging Levels](#-logging-levels)
- [Isolate Support](#-isolate-support)
- [Advanced Features](#-advanced-features)
- [Platform Support](#-platform-support)

---

## 🎯 Why Omni Logger?

Most Flutter apps start with `print()` or `debugPrint()`, then face these challenges:

- 📱 **No persistence** — Debug info disappears when the app closes
- 🔍 **Poor production visibility** — Can't diagnose user-reported issues
- ⚡ **Performance impact** — Verbose logging slowing down production builds
- 🔧 **Manual setup** — File rotation, compression, cleanup all manual

| Challenge | Omni Logger | Traditional |
|-----------|-------------|-------------|
| **Setup** | ✅ `AppLog.setup()` — zero config | ❌ Manual configuration |
| **File Management** | ✅ Auto rotation, compression, cleanup | ❌ Manual FileOutput setup |
| **Build Optimization** | ✅ Auto-adapts to debug/release modes | ❌ Same config for all builds |
| **Production Debugging** | ✅ Persistent logs | ❌ No production logging |

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
AppLog.setupForDatabaseIsolate(isolateName: 'drift_db');
AppLog.log('Database').d('Query executed successfully');

// Background isolate
AppLog.setupForBackgroundIsolate(isolateName: 'sync_worker');
AppLog.log('SyncService').w('Sync took longer than expected');
```

---

## 🔧 Advanced Features

### Setup Options

```dart
AppLog.setup();             // Auto-detect environment
AppLog.setupDevelopment();  // Debug mode with clean logs
AppLog.setupProduction();   // Minimal logging
AppLog.setupOff();          // Disable all logging
AppLog.setupVerbose();      // Maximum logging
```

### Runtime Control

```dart
AppLog.cleanAllLogs();   // Clean all log files
AppLog.printLogStats();  // Print log statistics
AppLog.checkHealth();    // Get health status
AppLog.reset();          // Reset logger
```

---

## 📱 Platform Support

| Platform | Console | File Logging |
|----------|---------|--------------|
| Android  | ✅      | ✅           |
| iOS      | ✅      | ✅           |
| Desktop  | ✅      | ✅           |
| Web      | ✅      | ❌ (by design) |

---

## Contributing

Contributions are welcome! Please submit pull requests to our [repository](https://github.com/Observability-Labs/omni_logger).

## License

MIT License — see [LICENSE](LICENSE) for details.

---
Built with ❤️ for the Flutter community