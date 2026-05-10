import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:omni_logger/omni_logger.dart';
import 'package:omni_logger/src/loggerManager/support/my_isolate_helpers.dart';
import 'package:path/path.dart' as path;

class MyLogFileBuildAndStats {
  /// Get log statistics for a directory
  static Map<String, dynamic> getLogStats(
    String logDirectory,
    String logFilePrefix,
  ) {
    try {
      final dir = Directory(logDirectory);
      if (!dir.existsSync()) {
        return {'error': 'Log directory does not exist'};
      }

      final files = dir
          .listSync()
          .whereType<File>()
          .where(
            (f) =>
                path.basename(f.path).startsWith(logFilePrefix) &&
                f.path.endsWith('.log'),
          )
          .toList();

      var totalSize = 0;
      DateTime? oldestFile;
      DateTime? newestFile;

      for (final file in files) {
        try {
          totalSize += file.lengthSync();
          final lastModified = file.lastModifiedSync();

          if (oldestFile == null || lastModified.isBefore(oldestFile)) {
            oldestFile = lastModified;
          }
          if (newestFile == null || lastModified.isAfter(newestFile)) {
            newestFile = lastModified;
          }
        } catch (e) {
          // Optionally log or debug this error in real usage
          // debugPrint('Error reading file info: $e');
        }
      }

      return {
        'logDirectory': logDirectory,
        'totalLogFiles': files.length,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
        'oldestLogFile': oldestFile?.toIso8601String(),
        'newestLogFile': newestFile?.toIso8601String(),
      };
    } catch (e) {
      return {'error': 'Failed to get log stats: $e'};
    }
  }

  /// Test logger setup
  static void testLogger(
    OmniLogger myLogger,
    bool isIsolate,
    String? isolateName,
  ) {
    final testLogger = myLogger.getLogger(className: 'AppLog');
    testLogger.i(
      'Logger setup successful in ${isIsolate ? 'isolate' : 'main'}: $isolateName',
    );
  }

  /// Create fallback logger
  static Logger createFallbackLogger() {
    return Logger(printer: SimplePrinter(), output: ConsoleOutput());
  }

  /// Build statistics map
  static Map<String, dynamic> buildStats(
    bool isSetup,
    String? isolateName,
    bool isIsolate,
    String? setupError,
    OmniLogger? instance,
  ) {
    final stats = <String, dynamic>{
      'isSetup': isSetup,
      'isolateName': isolateName,
      'isIsolate': isIsolate,
      'isHealthy': isHealthy(isSetup, instance),
    };

    if (setupError != null) {
      stats['setupError'] = setupError;
    }

    if (instance != null) {
      stats.addAll(instance.getLogStats());
    } else {
      stats['logger'] = null;
    }

    return stats;
  }

  /// Check if logging system is healthy
  static bool isHealthy(bool isSetup, OmniLogger? instance) {
    if (!isSetup) return false;
    return instance != null && !instance.hasInitializationFailed;
  }

  /// Update log level at runtime
  static bool updateLogLevel(
    OmniLogLevel newLevel,
    OmniLogger? instance,
    void Function(OmniLogger) registerLogger,
    String? isolateName,
  ) {
    try {
      if (instance == null) return false;

      final newConfig = instance.config.copyWith(level: newLevel);
      final newLogger = OmniLogger(newConfig);

      registerLogger(newLogger);

      if (kDebugMode) {
        final testLogger = newLogger.getLogger(className: 'AppLog');
        testLogger.i(
          'AppLog[$isolateName]: Log level updated to: ${newLevel.name}',
        );
      }

      return true;
    } catch (e) {
      MyLogIsolateHelpers.debugPrintIfNeeded('Failed to update log level: $e');
      return false;
    }
  }

  /// Update file logging at runtime
  static bool updateFileLogging(
    bool enabled,
    OmniLogger? instance,
    void Function(OmniLogger) registerLogger,
    String? isolateName,
  ) {
    try {
      if (instance == null) return false;

      final newConfig = instance.config.copyWith(enableFileLogging: enabled);
      final newLogger = OmniLogger(newConfig);

      newLogger.resetFileLogging();

      registerLogger(newLogger);

      if (kDebugMode) {
        final testLogger = newLogger.getLogger(className: 'AppLog');
        testLogger.i(
          'AppLog[$isolateName]: File logging ${enabled ? 'enabled' : 'disabled'}',
        );
      }

      return true;
    } catch (e) {
      MyLogIsolateHelpers.debugPrintIfNeeded(
        'Failed to update file logging: $e',
      );
      return false;
    }
  }
}
