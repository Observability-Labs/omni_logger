import 'dart:async';
import 'package:omni_logger/src/loggerConfig/logConfig/configure_log.dart';
import 'package:omni_logger/src/loggerManager/support/my_isolate_helpers.dart';
import 'package:omni_logger/src/loggerLevels/omni_log_levels.dart';
import 'package:omni_logger/src/loggerCore/logFiles/support/log_build_and_stats.dart';
import 'package:omni_logger/src/loggerCore/my_logger.dart';

/// Abstract interface for logger implementations
abstract interface class OmniLogger {
  //===================================================================//
  //========================== MAIN LOGGER ===========================//
  //===================================================================//

  /// Ensures the logger is fully initialized
  void ensureInitialized();

  /// Get the logger configuration
  OmniLogConfig get config;

  /// Get a logger instance for a specific class - returns MyLogger
  OmniLogger getLogger({required String className});

  /// Get current log file path if available
  String? get currentLogFilePath;

  /// Get log directory path if available
  String? get logDirectory;

  /// Check if file logging is working
  bool get isFileLoggingReady;

  /// Check if initialization has failed
  bool get hasInitializationFailed;

  /// Get last initialization error
  String? get lastInitError;

  /// Get comprehensive logging statistics
  Map<String, dynamic> getLogStats();

  // Print beautiful log statictics in console
  void printLogStats({required OmniLogger logger});

  /// Reset file logging (useful for testing or recovery)
  bool resetFileLogging();

  /// Dispose resources
  void dispose();

  /// Clean all Logs
  bool cleanAllLogs();

  //===================================================================//
  //========================== LOGGING METHODS =======================//
  //===================================================================//

  /// Log a trace message
  void t(dynamic message, {dynamic error, StackTrace? stackTrace});

  /// Log a debug message
  void d(dynamic message, {dynamic error, StackTrace? stackTrace});

  /// Log an info message
  void i(dynamic message, {dynamic error, StackTrace? stackTrace});

  /// Log a warning message
  void w(dynamic message, {dynamic error, StackTrace? stackTrace});

  /// Log an error message
  void e(dynamic message, {dynamic error, StackTrace? stackTrace});

  /// Log a fatal/wtf message
  void f(dynamic message, {dynamic error, StackTrace? stackTrace});

  /// Log with a specific level - ASYNC TO SUPPORT MIDDLEWARE
  Future<void> log(
    OmniLogLevel level,
    dynamic message, {
    dynamic error,
    StackTrace? stackTrace,
  });

  //===================================================================//
  //========================== LOGGING SETUP ==========================//
  //===================================================================//

  factory OmniLogger.auto({String? isolatePrefix}) {
    return OmniLoggerCore(OmniLogConfig.auto(isolatePrefix: isolatePrefix));
  }

  factory OmniLogger.autoDatabase({String isolatePrefix = 'db'}) {
    return OmniLoggerCore(
      OmniLogConfig.forDatabase(isolatePrefix: isolatePrefix),
    );
  }

  factory OmniLogger.autoBackground({String isolatePrefix = 'bg'}) {
    return OmniLoggerCore(
      OmniLogConfig.forBackground(isolatePrefix: isolatePrefix),
    );
  }

  factory OmniLogger.autoNetwork({String isolatePrefix = 'network'}) {
    return OmniLoggerCore(
      OmniLogConfig.forNetwork(isolatePrefix: isolatePrefix),
    );
  }

  // Additional factory constructors for specific modes
  factory OmniLogger.production({String? isolatePrefix}) {
    return OmniLoggerCore(
      OmniLogConfig.production(isolatePrefix: isolatePrefix),
    );
  }

  factory OmniLogger.debug({String? isolatePrefix}) {
    return OmniLoggerCore(OmniLogConfig.debug(isolatePrefix: isolatePrefix));
  }

  factory OmniLogger.profile({String? isolatePrefix}) {
    return OmniLoggerCore(OmniLogConfig.profile(isolatePrefix: isolatePrefix));
  }

  factory OmniLogger.off({String? isolatePrefix}) {
    return OmniLoggerCore(OmniLogConfig.off(isolatePrefix: isolatePrefix));
  }

  factory OmniLogger.remoteOnly({String? isolatePrefix}) {
    return OmniLoggerCore(
      OmniLogConfig.remoteOnly(isolatePrefix: isolatePrefix),
    );
  }

  // Default constructor delegate to implementation
  factory OmniLogger(OmniLogConfig config) {
    return OmniLoggerCore(config);
  }

  /// Update log level dynamically at runtime
  static bool updateLogLevel({
    required OmniLogLevel newLevel,
    required OmniLogger? instance,
    required void Function(OmniLogger) registerLogger,
    String? isolateName,
  }) {
    return MyLogFileBuildAndStats.updateLogLevel(
      newLevel,
      instance,
      registerLogger,
      isolateName ?? MyLogIsolateHelpers.isolateName,
    );
  }

  /// Enable or disable file logging at runtime
  static bool updateFileLogging({
    required bool enabled,
    required OmniLogger? instance,
    required void Function(OmniLogger) registerLogger,
    String? isolateName,
  }) {
    return MyLogFileBuildAndStats.updateFileLogging(
      enabled,
      instance,
      registerLogger,
      isolateName ?? MyLogIsolateHelpers.isolateName,
    );
  }

  //===================================================================//
  //======== Isolate-aware factory constructors =======================//
  //===================================================================//

  /// Get current isolate information
  static Map<String, dynamic> getIsolateInfo(
    String? isolateName,
    bool isIsolate,
  ) {
    return MyLogIsolateHelpers.getIsolateInfo(
      MyLogIsolateHelpers.isolateName,
      MyLogIsolateHelpers.isIsolate,
    );
  }

  /// Get the current isolate name directly
  static String get isolateName => MyLogIsolateHelpers.isolateName;

  /// Check if the current context is an isolate
  static bool get isIsolate => MyLogIsolateHelpers.isIsolate;

  /// Get formatted isolate information string
  static String formatIsolateInfo() {
    return MyLogIsolateHelpers.formatIsolateInfo();
  }

  /// Get current isolate name
  static String getCurrentIsolateName() {
    return MyLogIsolateHelpers.getCurrentIsolateName();
  }

  /// Check if running in isolate context
  static bool isRunningInIsolate() {
    return MyLogIsolateHelpers.isCurrentContextIsolate();
  }

  /// Detect and update isolate information
  static void detectIsolateInfo([String? providedName]) {
    MyLogIsolateHelpers.detectIsolateInfo(providedName);
  }

  //===================================================================//
  //============== Comprehensive statistics map =======================//
  //===================================================================//

  /// Build a comprehensive statistics map for the logger system
  static Map<String, dynamic> buildStats({
    required bool isSetup,
    String? isolateName,
    required bool isIsolate,
    String? setupError,
    OmniLogger? instance,
  }) {
    return MyLogFileBuildAndStats.buildStats(
      isSetup,
      isolateName ?? MyLogIsolateHelpers.isolateName,
      isIsolate,
      setupError,
      instance,
    );
  }

  //===================================================================//
  //=========================== FACTORY HELPERS =======================//
  //===================================================================//

  /// Print debug message with isolate name
  static void debugPrintIfNeeded(String message) {
    MyLogIsolateHelpers.debugPrintIfNeeded(message);
  }

  /// Print debug error with stack trace
  static void debugPrintError(String error, StackTrace stackTrace) {
    MyLogIsolateHelpers.debugPrintError(error, stackTrace);
  }

  /// Log reset message if instance is available
  static void logResetMessage(OmniLogger? instance) {
    MyLogIsolateHelpers.logResetMessage(instance);
  }

  /// Print logger stats
  static void debugPrintStats(OmniLogger myLogger) {
    MyLogIsolateHelpers.debugPrintStats(myLogger);
  }

  //===================================================================//
  //============== Failure and Health Checks ==========================//
  //===================================================================//

  /// Check if the logging system is healthy
  static bool isHealthy({required bool isSetup, OmniLogger? instance}) {
    return MyLogFileBuildAndStats.isHealthy(isSetup, instance);
  }

  /// Create a fallback [OmniLogger] instance (console-only, no file logging)
  static OmniLogger createFallbackLogger() {
    return OmniLoggerCore(OmniLogConfig.auto());
  }

  /// Log a test message indicating successful logger setup
  static void testLogger(
    OmniLogger myLogger, {
    bool? isIsolate,
    String? isolateName,
  }) {
    MyLogFileBuildAndStats.testLogger(
      myLogger,
      isIsolate ?? MyLogIsolateHelpers.isIsolate,
      isolateName ?? MyLogIsolateHelpers.isolateName,
    );
  }
}
