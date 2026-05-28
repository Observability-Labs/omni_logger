import 'package:flutter/foundation.dart';
import 'package:omni_logger/omni_logger.dart';
import 'package:omni_logger/src/loggerManager/support/my_log_directory.dart';

// coverage:ignore-start
// Enhanced AppLog with isolate awareness and beautiful log stats display
class OmniLoggerClient {
  static OmniLogger? _instance;

  /// Get the main logger instance - creates it automatically if needed
  static OmniLogger get instance {
    _instance ??= OmniLogger(OmniLogConfig.auto());
    return _instance!;
  }

  /// Returns an [OmniLogger] for the given [className].
  ///
  /// If [customMiddleware] is provided, it wraps the base logger using that
  /// custom logic. Otherwise, returns the plain logger.
  static OmniLogger log(
    String className, {
    OmniLogger Function(OmniLogger base)? customMiddleware,
  }) {
    final baseLogger = instance.getLogger(className: className);

    // Apply custom middleware if provided
    return customMiddleware != null ? customMiddleware(baseLogger) : baseLogger;
  }

  /// Convenience method - same as log() but shorter name
  static OmniLogger getLogger(String className) => log(className);

  /// Setup method (optional) - for explicit initialization if needed
  static Future<bool> setup({OmniLogger? omniLogger}) async {
    try {
      await MyLogDirectoryManage.init();
      _instance = omniLogger ?? OmniLogger(OmniLogConfig.auto());
      return true;
    } catch (e) {
      // Fallback to auto logger
      _instance = OmniLogger(OmniLogConfig.auto());
      return false;
    }
  }

  /// DEVELOPMENT SETUP
  static Future<bool> setupDevelopment({
    bool cleanLogsFirst = true,
    String? isolatePrefix,
  }) async {
    try {
      await MyLogDirectoryManage.init();
      if (cleanLogsFirst) {
        if (isSetup) {
          cleanAllLogs();
        }
        reset();
      }

      _instance = OmniLogger(OmniLogConfig.debug(isolatePrefix: isolatePrefix));

      final classLogger = OmniLoggerClient.log('AppLog');
      classLogger.i('🚀 Development logger setup complete');
      if (cleanLogsFirst) {
        classLogger.i('🧹 Started with clean log files');
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// CONDITIONAL CLEAN SETUP
  static Future<bool> setupWithConditionalClean({
    bool cleanInDebugMode = true,
    OmniLogger? myLogger,
  }) async {
    try {
      await MyLogDirectoryManage.init();
      // Clean logs only in debug mode
      if (kDebugMode && cleanInDebugMode && isSetup) {
        cleanAllLogs();
        reset();
      }

      // Setup the logger
      _instance = myLogger ?? OmniLogger(OmniLogConfig.auto());

      final classLogger = OmniLoggerClient.log('AppLog');
      if (kDebugMode && cleanInDebugMode) {
        classLogger.i('🧹 Debug mode: Started with clean logs');
      }
      classLogger.i('📊 Logger initialized successfully');

      return true;
    } catch (e) {
      // Fallback to auto logger
      _instance = OmniLogger(OmniLogConfig.auto());
      return false;
    }
  }

  /// Quick setup to disable all logging in the **main isolate only**.
  static Future<bool> setupOff({String? isolatePrefix}) async {
    try {
      await MyLogDirectoryManage.init();
      _instance = OmniLogger(OmniLogConfig.off(isolatePrefix: isolatePrefix));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Quick setup for minimal logging (errors + crashes only)
  static Future<bool> setupMinimal({String? isolatePrefix}) async {
    try {
      await MyLogDirectoryManage.init();
      _instance = OmniLogger(
        OmniLogConfig.production(isolatePrefix: isolatePrefix),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Quick setup for verbose logging (debug mode override)
  static Future<bool> setupVerbose({String? isolatePrefix}) async {
    try {
      await MyLogDirectoryManage.init();
      _instance = OmniLogger(OmniLogConfig.debug(isolatePrefix: isolatePrefix));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Setup with custom log level - for fine control
  static Future<bool> setupCustomLevel({
    required OmniLogLevel level,
    String? isolatePrefix,
    bool? enableFileLogging,
    bool? enableConsoleLogging,
  }) async {
    try {
      await MyLogDirectoryManage.init();
      _instance = OmniLogger(
        OmniLogConfig.custom(
          mode: OmniLogConfigManager.getCurrentMode(),
          isolatePrefix: isolatePrefix,
          levelOverride: level,
          fileLoggingOverride: enableFileLogging,
          consoleLoggingOverride: enableConsoleLogging,
        ),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Setup for database isolate
  static Future<bool> setupForDatabaseIsolate({
    String isolateName = 'db_isolate',
    OmniLogLevel? logLevel,
  }) async {
    try {
      await MyLogDirectoryManage.init();
      final config = logLevel != null
          ? OmniLogConfig.forDatabase(
              isolatePrefix: isolateName,
            ).copyWith(level: logLevel)
          : OmniLogConfig.forDatabase(isolatePrefix: isolateName);
      _instance = OmniLogger(config);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Setup for background isolate
  static Future<bool> setupForBackgroundIsolate({
    String isolateName = 'bg_isolate',
    OmniLogLevel? logLevel,
  }) async {
    try {
      await MyLogDirectoryManage.init();
      final config = logLevel != null
          ? OmniLogConfig.forBackground(
              isolatePrefix: isolateName,
            ).copyWith(level: logLevel)
          : OmniLogConfig.forBackground(isolatePrefix: isolateName);
      _instance = OmniLogger(config);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Setup for network isolate
  static Future<bool> setupForNetworkIsolate({
    String isolateName = 'network_isolate',
    OmniLogLevel? logLevel,
  }) async {
    try {
      await MyLogDirectoryManage.init();
      final config = logLevel != null
          ? OmniLogConfig.forNetwork(
              isolatePrefix: isolateName,
            ).copyWith(level: logLevel)
          : OmniLogConfig.forNetwork(isolatePrefix: isolateName);
      _instance = OmniLogger(config);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Setup for production mode - minimal logging, optimized for performance
  static Future<bool> setupProduction({String? isolatePrefix}) async {
    try {
      await MyLogDirectoryManage.init();
      _instance = OmniLogger(
        OmniLogConfig.production(isolatePrefix: isolatePrefix),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Setup for profile mode - moderate logging for performance analysis
  static Future<bool> setupProfile({String? isolatePrefix}) async {
    try {
      await MyLogDirectoryManage.init();
      _instance = OmniLogger(
        OmniLogConfig.profile(isolatePrefix: isolatePrefix),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Setup for remote-only logging - logs are active but nothing saved locally
  static Future<bool> setupRemoteOnly({String? isolatePrefix}) async {
    try {
      await MyLogDirectoryManage.init();
      _instance = OmniLogger(
        OmniLogConfig.remoteOnly(isolatePrefix: isolatePrefix),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Setup with specific LogMode for advanced control
  static Future<bool> setupWithMode({
    required OmniLogMode mode,
    String? isolatePrefix,
    OmniLogLevel? levelOverride,
    bool? fileLoggingOverride,
    bool? consoleLoggingOverride,
  }) async {
    try {
      await MyLogDirectoryManage.init();
      _instance = OmniLogger(
        OmniLogConfig.custom(
          mode: mode,
          isolatePrefix: isolatePrefix,
          levelOverride: levelOverride,
          fileLoggingOverride: fileLoggingOverride,
          consoleLoggingOverride: consoleLoggingOverride,
        ),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
  // ==================== LOGGER SETUP METHODS ====================

  /// Clean all logs across all isolates (if supported by underlying logger)
  static bool cleanAllLogs() {
    try {
      final logger = instance;
      logger.ensureInitialized();
      final success = logger.cleanAllLogs();

      if (success) {
        final classLogger = OmniLoggerClient.log('AppLog');
        classLogger.i('🧹 All log files cleaned successfully');
        return true;
      } else {
        final classLogger = OmniLoggerClient.log('AppLog');
        classLogger.w('⚠️ Failed to clean some log files');
        return false;
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AppLog: Failed to clean logs: $e');
        debugPrint('Stack trace: $st');
      }
      return false;
    }
  }

  /// Print nicely formatted log statistics (for debugging/log file inspection)
  static void printLogFileStats() {
    try {
      final logger = instance;
      logger.ensureInitialized();

      final classLogger = OmniLoggerClient.log('AppLog');
      classLogger.i('📊 Printing log file statistics...');

      logger.printLogStats(logger: classLogger);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AppLog: Failed to print log statistics: $e');
        debugPrint('Stack trace: $st');
      }
    }
  }

  /// CHECK LOG HEALTH - Verify logging system is working properly
  static Map<String, dynamic> checkLogHealth() {
    try {
      final fileCount = OmniLoggerClientExtension.getLogFileCount();
      final totalSizeMB = OmniLoggerClientExtension.getTotalLogSizeMB();
      final isHealthy = isSetup && !isLoggingDisabled;

      return {
        'isHealthy': isHealthy,
        'fileCount': fileCount,
        'totalSizeMB': totalSizeMB,
        'isSetup': isSetup,
        'isLoggingDisabled': isLoggingDisabled,
        'currentLevel': currentLevel?.name,
        'message': isHealthy
            ? '✅ Logging system is healthy'
            : '❌ Logging system has issues',
      };
    } catch (e) {
      return {
        'isHealthy': false,
        'error': e.toString(),
        'message': '❌ Error checking log health',
      };
    }
  }

  /// Quick setup to disable all logging in the **main isolate only**.

  /// Get comprehensive system status
  static Map<String, dynamic> getSystemStatus() {
    final health = checkLogHealth();

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'health': health,
      'config': {
        'level': currentLevel?.name,
        'mode': currentMode?.name,
        'isVerbose': isVerbose,
        'summary': configSummary,
      },
      'stats': OmniLoggerClientExtension.logStats,
    };
  }

  /// Reset the logger (useful for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }

  /// Check if logger is initialized
  static bool get isSetup => _instance != null;

  /// Get current log level (useful for runtime decisions)
  static OmniLogLevel? get currentLevel => _instance?.config.level;

  /// Quick check if logging is effectively disabled
  static bool get isLoggingDisabled =>
      _instance?.config.isLoggingDisabled ?? false;

  /// Get current configuration (for debugging)
  static OmniLogConfig? get currentConfig => _instance?.config;

  /// Get current log mode
  static OmniLogMode? get currentMode => _instance?.config.mode;

  /// Check if current config is verbose
  static bool get isVerbose => _instance?.config.isVerbose ?? false;

  /// Get configuration summary for debugging
  static String get configSummary =>
      _instance?.config.summary ?? 'Not initialized';
}

// Extension for log statistics and monitoring functionality
extension OmniLoggerClientExtension on OmniLoggerClient {
  /// GET LOG FILE COUNT - Check how many log files exist
  static int getLogFileCount() {
    try {
      final stats = OmniLoggerClient.instance.getLogStats();
      return stats['totalLogFiles'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// GET TOTAL LOG SIZE - Check total size of all log files
  static double getTotalLogSizeMB() {
    try {
      final stats = OmniLoggerClient.instance.getLogStats();
      return stats['totalSizeMB'] as double? ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// GET OLDEST LOG FILE DATE
  static DateTime? getOldestLogDate() {
    try {
      final stats = OmniLoggerClient.instance.getLogStats();
      final oldestStr = stats['oldestLogDate'] as String?;
      return oldestStr != null ? DateTime.tryParse(oldestStr) : null;
    } catch (e) {
      return null;
    }
  }

  /// GET NEWEST LOG FILE DATE
  static DateTime? getNewestLogDate() {
    try {
      final stats = OmniLoggerClient.instance.getLogStats();
      final newestStr = stats['newestLogDate'] as String?;
      return newestStr != null ? DateTime.tryParse(newestStr) : null;
    } catch (e) {
      return null;
    }
  }

  /// GET LOG FILES LIST with details
  static List<Map<String, dynamic>> getLogFilesList() {
    try {
      final stats = OmniLoggerClient.instance.getLogStats();
      return (stats['logFiles'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
    } catch (e) {
      return [];
    }
  }

  /// GET DETAILED LOG STATISTICS
  static Map<String, dynamic> getDetailedStats() {
    try {
      final stats = OmniLoggerClient.instance.getLogStats();
      final fileCount = getLogFileCount();
      final totalSizeMB = getTotalLogSizeMB();
      final oldestDate = getOldestLogDate();
      final newestDate = getNewestLogDate();

      return {
        'summary': {
          'fileCount': fileCount,
          'totalSizeMB': totalSizeMB,
          'averageFileSizeMB': fileCount > 0 ? totalSizeMB / fileCount : 0.0,
        },
        'dateRange': {
          'oldest': oldestDate?.toIso8601String(),
          'newest': newestDate?.toIso8601String(),
          'spanDays': oldestDate != null && newestDate != null
              ? newestDate.difference(oldestDate).inDays
              : null,
        },
        'rawStats': stats,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// CHECK IF LOG CLEANUP IS NEEDED based on file count or size
  static bool isCleanupNeeded({int maxFiles = 50, double maxSizeMB = 100.0}) {
    try {
      final fileCount = getLogFileCount();
      final totalSize = getTotalLogSizeMB();

      return fileCount > maxFiles || totalSize > maxSizeMB;
    } catch (e) {
      return false;
    }
  }

  /// GET CLEANUP RECOMMENDATIONS
  static Map<String, dynamic> getCleanupRecommendations({
    int maxFiles = 50,
    double maxSizeMB = 100.0,
  }) {
    try {
      final fileCount = getLogFileCount();
      final totalSize = getTotalLogSizeMB();
      final needsCleanup = isCleanupNeeded(
        maxFiles: maxFiles,
        maxSizeMB: maxSizeMB,
      );

      return {
        'needsCleanup': needsCleanup,
        'current': {'fileCount': fileCount, 'totalSizeMB': totalSize},
        'limits': {'maxFiles': maxFiles, 'maxSizeMB': maxSizeMB},
        'recommendations': needsCleanup
            ? [
                if (fileCount > maxFiles)
                  'Consider cleaning old log files (current: $fileCount, limit: $maxFiles)',
                if (totalSize > maxSizeMB)
                  'Consider cleaning large log files (current: ${totalSize.toStringAsFixed(2)}MB, limit: ${maxSizeMB}MB)',
              ]
            : ['Log files are within acceptable limits'],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'needsCleanup': false,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get raw log statistics (useful for programmatic access)
  static Map<String, dynamic> get logStats {
    try {
      final logger = OmniLoggerClient.instance;
      logger.ensureInitialized();
      return logger.getLogStats();
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// EXPORT LOG STATS as JSON string
  static String exportStatsAsJson() {
    try {
      final stats = getDetailedStats();
      // Assuming you have a JSON encoder available
      return stats.toString(); // Replace with proper JSON encoding
    } catch (e) {
      return '{"error": "${e.toString()}"}';
    }
  }

  /// PRINT FORMATTED STATS SUMMARY to console
  static void printStatsSummary() {
    try {
      final stats = getDetailedStats();
      final summary = stats['summary'] as Map<String, dynamic>;
      final dateRange = stats['dateRange'] as Map<String, dynamic>;

      if (kDebugMode) {
        print('📊 Log Statistics Summary');
        print('═══════════════════════════');
        print('📁 Files: ${summary['fileCount']}');
        print(
          '💾 Total Size: ${(summary['totalSizeMB'] as double).toStringAsFixed(2)} MB',
        );
        print(
          '📏 Avg File Size: ${(summary['averageFileSizeMB'] as double).toStringAsFixed(2)} MB',
        );
      }

      if (dateRange['oldest'] != null && dateRange['newest'] != null) {
        if (kDebugMode) {
          print('📅 Date Range: ${dateRange['spanDays']} days');
          print('🕐 Oldest: ${dateRange['oldest']}');
          print('🕐 Newest: ${dateRange['newest']}');
        }
      }

      final cleanup = getCleanupRecommendations();
      if (cleanup['needsCleanup'] as bool) {
        if (kDebugMode) {
          print('⚠️  Cleanup Needed');
        }

        final recommendations = cleanup['recommendations'] as List;
        for (final rec in recommendations) {
          if (kDebugMode) {
            print('   • $rec');
          }
        }
      } else {
        if (kDebugMode) {
          print('✅ Log files are within acceptable limits');
        }
      }
      if (kDebugMode) {
        print('═══════════════════════════');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error printing stats summary: $e');
      }
    }
  }
}


// Without Data Privacy Shield
// coverage:ignore-end

// class AppLog {
//   static MyLogger? _instance;

//   /// Get the main logger instance - creates it automatically if needed
//   static MyLogger get instance {
//     _instance ??= MyLogger(MyLogConfig.auto());
//     return _instance!;
//   }

//   /// Get a logger for a specific class - your existing interface!
//   static MyLogger log(String className) {
//     return instance.getLogger(className: className);
//   }

//   /// Convenience method - same as log() but shorter name
//   static MyLogger getLogger(String className) => log(className);

//   /// Setup method (optional) - for explicit initialization if needed
//   /// Setup main thread or isolate
//   static bool setup({MyLogger? myLogger}) {
//     try {
//       _instance = myLogger ?? MyLogger(MyLogConfig.auto());
//       return true;
//     } catch (e) {
//       // Fallback to auto logger
//       _instance = MyLogger(MyLogConfig.auto());
//       return false;
//     }
//   }

//   /// 🧹 CLEAN ALL LOGS API - Add this to your existing AppLog class
//   /// Clean all log files (useful for development/testing)
//   static bool cleanAllLogs() {
//     try {
//       // Ensure logger instance exists
//       final logger = instance;
//       logger.ensureInitialized();
//       // Get the MyLoggerCore instance to access its file output
//       // Use the static file output to clean logs
//       final success = logger.cleanAllLogs();

//       if (success) {
//         final classLogger = AppLog.log('AppLog');
//         classLogger.i('🧹 All log files cleaned successfully');
//         return true;
//       } else {
//         final classLogger = AppLog.log('AppLog');
//         classLogger.w('⚠️ Failed to clean some log files');
//         return false;
//       }
//     } catch (e, st) {
//       if (kDebugMode) {
//         debugPrint('AppLog: Failed to clean logs: $e');
//         debugPrint('Stack trace: $st');
//       }
//       return false;
//     }
//   }

//   /// 🔄 DEVELOPMENT SETUP - Clean logs and setup fresh logger
//   /// Perfect for development when you want to start with clean logs
//   static bool setupDevelopment({
//     bool cleanLogsFirst = true,
//     String? isolatePrefix,
//   }) {
//     try {
//       // First, clean existing logs if requested
//       if (cleanLogsFirst) {
//         // Try to clean with existing instance first
//         if (isSetup) {
//           cleanAllLogs();
//         }

//         // Reset the instance
//         reset();
//       }

//       // Setup new debug logger
//       _instance = MyLogger(MyLogConfig.debug(isolatePrefix: isolatePrefix));

//       // Log the fresh start
//       final classLogger = AppLog.log('AppLog');
//       classLogger.i('🚀 Development logger setup complete');
//       if (cleanLogsFirst) {
//         classLogger.i('🧹 Started with clean log files');
//       }

//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// 🔧 CONDITIONAL CLEAN SETUP - Clean logs only in debug mode
//   /// This is probably what you want for your main app setup
//   static bool setupWithConditionalClean({
//     bool cleanInDebugMode = true,
//     MyLogger? myLogger,
//   }) {
//     try {
//       // Clean logs only in debug mode
//       if (kDebugMode && cleanInDebugMode && isSetup) {
//         cleanAllLogs();
//         reset();
//       }

//       // Setup the logger
//       _instance = myLogger ?? MyLogger(MyLogConfig.auto());

//       final classLogger = AppLog.log('AppLog');
//       if (kDebugMode && cleanInDebugMode) {
//         classLogger.i('🧹 Debug mode: Started with clean logs');
//       }
//       classLogger.i('📊 Logger initialized successfully');

//       return true;
//     } catch (e) {
//       // Fallback to auto logger
//       _instance = MyLogger(MyLogConfig.auto());
//       return false;
//     }
//   }

//   /// Print nicely formatted log statistics (for debugging/log file inspection)
//   static void printLogFileStats() {
//     try {
//       // Ensure logger instance exists and is properly initialized
//       final logger = instance;
//       logger.ensureInitialized();

//       // Use class-specific logger to label output - this creates consistent context
//       final classLogger = AppLog.log('AppLog');
//       classLogger.i('📊 Printing log file statistics...');

//       // Print the pretty log stats to console using the same logger instance
//       // This ensures consistent configuration and avoids creating separate loggers
//       logger.printLogStats(
//           logger: classLogger); // Pass the class-specific logger
//     } catch (e, st) {
//       // Fallback error handling - but avoid creating new logger instances
//       if (kDebugMode) {
//         debugPrint('AppLog: Failed to print log statistics: $e');
//         debugPrint('Stack trace: $st');
//       }
//     }
//   }

//   /// 📊 GET LOG FILE COUNT - Check how many log files exist
//   static int getLogFileCount() {
//     try {
//       final stats = instance.getLogStats();
//       return stats['totalLogFiles'] as int? ?? 0;
//     } catch (e) {
//       return 0;
//     }
//   }

//   /// 📏 GET TOTAL LOG SIZE - Check total size of all log files
//   static double getTotalLogSizeMB() {
//     try {
//       final stats = instance.getLogStats();
//       return stats['totalSizeMB'] as double? ?? 0.0;
//     } catch (e) {
//       return 0.0;
//     }
//   }

//   /// 🔍 CHECK LOG HEALTH - Verify logging system is working properly
//   static Map<String, dynamic> checkLogHealth() {
//     try {
//       final fileCount = getLogFileCount();
//       final totalSizeMB = getTotalLogSizeMB();
//       final isHealthy = isSetup && !isLoggingDisabled;

//       return {
//         'isHealthy': isHealthy,
//         'fileCount': fileCount,
//         'totalSizeMB': totalSizeMB,
//         'isSetup': isSetup,
//         'isLoggingDisabled': isLoggingDisabled,
//         'currentLevel': currentLevel?.name,
//         'message': isHealthy
//             ? '✅ Logging system is healthy'
//             : '❌ Logging system has issues',
//       };
//     } catch (e) {
//       return {
//         'isHealthy': false,
//         'error': e.toString(),
//         'message': '❌ Error checking log health',
//       };
//     }
//   }

//   /// Quick setup to disable all logging in the **main isolate only**.
//   ///
//   /// ⚠️ NOTE: This only disables logging in the main isolate. Logs from other
//   /// isolates (e.g., database, background, network) will **still be active**
//   /// unless they are also configured to use an "off" configuration.
//   ///
//   /// ✅ To fully disable logging across your app:
//   /// - Use `MyLogConfig.off()` (or similar off-config logic) when setting up
//   ///   loggers in other isolates, network, background processes.
//   /// Also, if a log is enabled inside a package, such as background_worker
//   /// then inside that package we can disable log as well.
//   static bool setupOff({String? isolatePrefix}) {
//     try {
//       _instance = MyLogger(MyLogConfig.off(isolatePrefix: isolatePrefix));
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Quick setup for minimal logging (errors + crashes only)
//   static bool setupMinimal({String? isolatePrefix}) {
//     try {
//       _instance =
//           MyLogger(MyLogConfig.production(isolatePrefix: isolatePrefix));
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Quick setup for verbose logging (debug mode override)
//   static bool setupVerbose({String? isolatePrefix}) {
//     try {
//       _instance = MyLogger(MyLogConfig.debug(isolatePrefix: isolatePrefix));
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Setup with custom log level - for fine control
//   static bool setupCustomLevel({
//     required OmniLogLevel level,
//     String? isolatePrefix,
//     bool? enableFileLogging,
//     bool? enableConsoleLogging,
//   }) {
//     try {
//       _instance = MyLogger(MyLogConfig.custom(
//         mode: LogConfigManager.getCurrentMode(),
//         isolatePrefix: isolatePrefix,
//         levelOverride: level,
//         fileLoggingOverride: enableFileLogging,
//         consoleLoggingOverride: enableConsoleLogging,
//       ));
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Setup for database isolate
//   static bool setupForDatabaseIsolate({
//     String isolateName = 'db_isolate',
//     OmniLogLevel? logLevel, // Optional override
//   }) {
//     try {
//       final config = logLevel != null
//           ? MyLogConfig.forDatabase(isolatePrefix: isolateName)
//               .copyWith(level: logLevel)
//           : MyLogConfig.forDatabase(isolatePrefix: isolateName);
//       _instance = MyLogger(config);
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Setup for background isolate
//   static bool setupForBackgroundIsolate({
//     String isolateName = 'bg_isolate',
//     OmniLogLevel? logLevel, // Optional override
//   }) {
//     try {
//       final config = logLevel != null
//           ? MyLogConfig.forBackground(isolatePrefix: isolateName)
//               .copyWith(level: logLevel)
//           : MyLogConfig.forBackground(isolatePrefix: isolateName);
//       _instance = MyLogger(config);
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Setup for network isolate
//   static bool setupForNetworkIsolate({
//     String isolateName = 'network_isolate',
//     OmniLogLevel? logLevel, // Optional override
//   }) {
//     try {
//       final config = logLevel != null
//           ? MyLogConfig.forNetwork(isolatePrefix: isolateName)
//               .copyWith(level: logLevel)
//           : MyLogConfig.forNetwork(isolatePrefix: isolateName);
//       _instance = MyLogger(config);
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Setup for production mode - minimal logging, optimized for performance
//   static bool setupProduction({String? isolatePrefix}) {
//     try {
//       _instance =
//           MyLogger(MyLogConfig.production(isolatePrefix: isolatePrefix));
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Setup for profile mode - moderate logging for performance analysis
//   static bool setupProfile({String? isolatePrefix}) {
//     try {
//       _instance = MyLogger(MyLogConfig.profile(isolatePrefix: isolatePrefix));
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Setup for remote-only logging - logs are active but nothing saved locally
//   static bool setupRemoteOnly({String? isolatePrefix}) {
//     try {
//       _instance =
//           MyLogger(MyLogConfig.remoteOnly(isolatePrefix: isolatePrefix));
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Setup with specific LogMode for advanced control
//   static bool setupWithMode({
//     required LogMode mode,
//     String? isolatePrefix,
//     OmniLogLevel? levelOverride,
//     bool? fileLoggingOverride,
//     bool? consoleLoggingOverride,
//   }) {
//     try {
//       _instance = MyLogger(MyLogConfig.custom(
//         mode: mode,
//         isolatePrefix: isolatePrefix,
//         levelOverride: levelOverride,
//         fileLoggingOverride: fileLoggingOverride,
//         consoleLoggingOverride: consoleLoggingOverride,
//       ));
//       return true;
//     } catch (e) {
//       return false;
//     }
//   }

//   /// Reset the logger (useful for testing)
//   static void reset() {
//     _instance?.dispose();
//     _instance = null;
//   }

//   /// Check if logger is initialized
//   static bool get isSetup => _instance != null;

//   /// Get current log level (useful for runtime decisions)
//   static OmniLogLevel? get currentLevel => _instance?.config.level;

//   /// Quick check if logging is effectively disabled
//   static bool get isLoggingDisabled =>
//       _instance?.config.isLoggingDisabled ?? false;

//   /// Get current configuration (for debugging)
//   static MyLogConfig? get currentConfig => _instance?.config;

//   /// Get current log mode
//   static LogMode? get currentMode => _instance?.config.mode;

//   /// Check if current config is verbose
//   static bool get isVerbose => _instance?.config.isVerbose ?? false;

//   /// Get configuration summary for debugging
//   static String get configSummary =>
//       _instance?.config.summary ?? 'Not initialized';

//   /// Get raw log statistics (useful for programmatic access)
//   static Map<String, dynamic> get logStats {
//     try {
//       final logger = instance;
//       logger.ensureInitialized();
//       return logger.getLogStats();
//     } catch (e) {
//       return {'error': e.toString()};
//     }
//   }
// }



