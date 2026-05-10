// USAGE EXAMPLE
//
// IMPORTANT RECOMMENDATION:
// If you're using basic logging only, rename `AppLogBasic` to `AppLog`.
// This makes it easier to upgrade to the full-featured `AppLog` class later
// without having to refactor your codebase.

// ===============USAGE FOR BASIC==============================
// Future<void> main(List<String> args) async {
//   runZonedGuarded<Future<void>>(() async {
//     WidgetsFlutterBinding.ensureInitialized();
//
//     AppLogBasic.setup();
//     AppLogBasic.printLogFileStats();
//     AppLogBasic.printStatsSummary();
//   }, (error, stack) {
//     // Handle uncaught errors here
//     if (kDebugMode) {
//       print('Uncaught error: $error');
//     }
//     if (kDebugMode) {
//       print('Stack trace: $stack');
//     }
//   });
// }

import 'package:omni_logger/omni_logger.dart';

class AppLog {
  static OmniLogger get instance => OmniLoggerClient.instance;

  static OmniLogger log(String className) {
    return OmniLoggerClient.log(className);
  }

  // ==================== BASIC SETUP METHODS ====================

  /// Simple setup - auto-detects environment and configures appropriately
  static bool setup({String? isolatePrefix}) => OmniLoggerClient.setup(
    omniLogger: OmniLogger(OmniLogConfig.auto(isolatePrefix: isolatePrefix)),
  );

  /// Development setup with clean logs
  static bool setupDevelopment({String? isolatePrefix}) =>
      OmniLoggerClient.setupDevelopment(isolatePrefix: isolatePrefix);

  /// Production setup - minimal logging
  static bool setupProduction({String? isolatePrefix}) =>
      OmniLoggerClient.setupProduction(isolatePrefix: isolatePrefix);

  /// Turn off all logging
  static bool setupOff({String? isolatePrefix}) =>
      OmniLoggerClient.setupOff(isolatePrefix: isolatePrefix);

  // ==================== BASIC UTILITIES ====================

  /// Clean all log files
  static bool cleanAllLogs() => OmniLoggerClient.cleanAllLogs();

  /// Check if logger is setup
  static bool get isSetup => OmniLoggerClient.isSetup;

  /// Get current log level
  static OmniLogLevel? get currentLevel => OmniLoggerClient.currentLevel;

  /// Check if logging is disabled
  static bool get isLoggingDisabled => OmniLoggerClient.isLoggingDisabled;

  /// Reset logger (useful for testing)
  static void reset() => OmniLoggerClient.reset();

  // ==================== BASIC STATS ====================

  /// Print basic log statistics
  static void printLogStats() => OmniLoggerClient.printLogFileStats();

  /// Get basic health check
  static Map<String, dynamic> checkHealth() =>
      OmniLoggerClient.checkLogHealth();

  // ==================== SPECIALIZED SETUP METHODS ====================
  /// Setup for database isolate
  static bool setupForDatabaseIsolate({
    String isolateName = 'db_isolate',
    OmniLogLevel? logLevel,
  }) => OmniLoggerClient.setupForDatabaseIsolate(
    isolateName: isolateName,
    logLevel: logLevel,
  );

  /// Setup for background isolate
  static bool setupForBackgroundIsolate({
    String isolateName = 'bg_isolate',
    OmniLogLevel? logLevel,
  }) => OmniLoggerClient.setupForBackgroundIsolate(
    isolateName: isolateName,
    logLevel: logLevel,
  );
}
