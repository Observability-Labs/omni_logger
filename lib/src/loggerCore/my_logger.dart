// Tutorial: https://medium.com/nerd-for-tech/implement-service-locator-design-pattern-with-get-it-flutter-5e50671bbbcb

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:omni_logger/omni_logger.dart';
import 'package:omni_logger/src/loggerCore/logFiles/log_file.dart';

import 'package:omni_logger/src/loggerCore/support/dev_printer.dart';
import 'package:omni_logger/src/loggerCore/support/json_printer.dart';
import 'package:omni_logger/src/loggerCore/support/prod_printer.dart';

///==============================================================================
/// LOGGER CONFIGURATION OVERVIEW
///==============================================================================
///
/// Centralized logging setup for your Flutter application, adaptable across
/// development, testing, and production environments.
///
/// Key Features:
/// - Console and optional file-based logging.
/// - Auto-detects environment (debug, profile, release).
/// - Log level and file retention policies based on environment.
/// - Optional integration with error reporting tools (e.g., Sentry).
///
/// Configuration Parameters:
/// -----------------------------------------------------------------------------
/// - `level`: Minimum severity to log (`debug`, `info`, `error`, etc.).
/// - `isProduction`: Inferred from Flutter build mode:
///     - `true` in release mode
///     - `false` in debug/profile modes
/// - `maxLogFiles`: Number of log files to retain:
///     - 7 days in development
///     - 1 day in production
/// - `enableFileLogging`: Whether to save logs to local files:
///     - Defaults to `false` in development
///     - Defaults to `true` in production
///     - Can be overridden manually
///
/// Notes:
/// - Console logging is always enabled.
/// - File logging is automatically disabled on the web.
///==============================================================================

///==============================================================================
/// PRODUCTION READINESS CHECKLIST
///==============================================================================
/// ✔ Review and adjust logger settings before publishing your app.
/// ✔ Set `log level` to `info` or higher in production.
/// ✔ Avoid logging sensitive data (e.g., tokens, passwords, PII).
/// ✔ Sanitize log output if necessary.
/// ✔ Integrate with crash/error tracking tools (e.g., Sentry):
///    - Capture uncaught exceptions
///    - Send critical logs and errors
///    - Avoid sending sensitive data in reports
///==============================================================================

///==============================================================================
/// ENVIRONMENT AUTO-DETECTION
///==============================================================================
///
/// `isProduction` is automatically set based on Flutter build mode:
/// - `release` → production
/// - `debug` / `profile` → development/testing
///
/// Behavior such as log levels and file retention adapts accordingly.
/// No manual toggling required.
///==============================================================================

class OmniLoggerCore implements OmniLogger {
  @override
  final OmniLogConfig config;

  static OmniFileOutput? _fileOutput;
  static bool _initializationFailed = false;
  static String? _lastInitError;

  // Internal logger instance for this class
  Logger? _internalLogger;
  final String _className; // Made non-nullable with default

  // Updated constructor to ensure className is always set
  OmniLoggerCore(this.config, [String? className])
    : _className = className ?? 'App';

  @override
  OmniLogger getLogger({required String className}) {
    // Return a new MyLoggerCore instance configured for the specific class
    return OmniLoggerCore(config, className);
  }

  @override
  void ensureInitialized() {
    // Force creation of internal logger which initializes _fileOutput
    _logger;
  }

  /// Get the internal Logger instance (lazy initialization)
  Logger get _logger {
    return _internalLogger ??= _createInternalLogger();
  }

  Logger _createInternalLogger() {
    final OmniLogLevel selectedLevel = config.level; // Fixed: use OmniLogLevel

    // Choose printer based on configuration - now _className is always set
    final LogPrinter printer = _getPrinter(_className);

    final outputs = <LogOutput>[];

    // Console output
    if (config.enableConsoleLogging) {
      outputs.add(ConsoleOutput());
    }

    // File output (skip on web)
    if (!kIsWeb && config.enableFileLogging && !_initializationFailed) {
      try {
        _fileOutput ??= OmniFileOutput.createSync(
          maxLogFiles: config.maxLogFiles,
          maxFileSizeMB: config.maxFileSizeMB,
          enableCompression: config.enableCompression,
          logFilePrefix: config.logFilePrefix,
          logRetentionDays: config.logRetentionDays,
        );

        if (_fileOutput != null) {
          outputs.add(_fileOutput!);
        } else {
          _initializationFailed = true;
          _lastInitError = 'Failed to create MyFileOutput instance';
        }
      } catch (e, stackTrace) {
        _initializationFailed = true;
        _lastInitError = 'Exception during file output creation: $e';
        // coverage:ignore-start
        if (kDebugMode) {
          debugPrint('MyLogger: $_lastInitError');
          debugPrint('Stack trace: $stackTrace');
        }
        // coverage:ignore-end
      }
    }

    // Production log filter
    LogFilter? filter;
    if (config.mode == OmniLogMode.production) {
      filter = ProductionFilter();
    }

    // Fallback: ensure at least console logging is available
    if (outputs.isEmpty) {
      outputs.add(ConsoleOutput());
    }

    return Logger(
      printer: printer,
      level: selectedLevel.toLoggerLevel(), // Convert OmniLogLevel to Level
      output: MultiOutput(outputs),
      filter: filter,
    );
  }

  LogPrinter _getPrinter(String className) {
    if (config.enableJsonLogging) {
      return JsonClassNamePrinter(className);
    } else if (config.mode == OmniLogMode.production) {
      return ProductionClassNamePrinter(className);
    } else {
      return DevClassNamePrinter(className);
    }
  }

  //===================================================================//
  //========================== LOGGING METHODS =======================//
  //===================================================================//
  @override
  void t(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  @override
  void d(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  @override
  void i(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  @override
  void w(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  @override
  void e(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  @override
  void f(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  @override
  Future<void> log(
    OmniLogLevel level,
    dynamic message, {
    dynamic error,
    StackTrace? stackTrace,
  }) async {
    _logger.log(
      level.toLoggerLevel(),
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }
  //===================================================================//
  //========================== EXISTING METHODS ======================//
  //===================================================================//

  @override
  String? get currentLogFilePath => _fileOutput?.currentLogFilePath;

  @override
  String? get logDirectory => _fileOutput?.logDirectory;

  @override
  bool get isFileLoggingReady => _fileOutput?.isReady ?? false;

  @override
  bool get hasInitializationFailed => _initializationFailed;

  @override
  String? get lastInitError => _lastInitError;

  @override
  Map<String, dynamic> getLogStats() {
    try {
      // Get base stats from file output if available
      Map<String, dynamic> stats = {};

      if (_fileOutput != null) {
        // Use the MyFileOutput's getLogStats method
        stats = _fileOutput!.getLogStats();
      } else {
        // Fallback stats when file output is not available
        stats = {
          'error': 'File output not initialized',
          'fileLoggingReady': false,
          'initializationFailed': _initializationFailed,
          'lastInitError': _lastInitError,
        };
      }

      // Add MyLoggerCore specific information
      stats.addAll({
        'className': _className,
        'fileLoggingReady': isFileLoggingReady,
        'initializationFailed': _initializationFailed,
        'lastInitError': _lastInitError,
        'config': {
          'level': config.level.name,
          'enableConsoleLogging': config.enableConsoleLogging,
          'enableFileLogging': config.enableFileLogging,
          'enableJsonLogging': config.enableJsonLogging,
          'mode': config.mode.name,
          'maxLogFiles': config.maxLogFiles,
          'maxFileSizeMB': config.maxFileSizeMB,
          'enableCompression': config.enableCompression,
          'logFilePrefix': config.logFilePrefix,
          'logRetentionDays': config.logRetentionDays,
        },
      });

      return stats;
    } catch (e, stackTrace) {
      // coverage:ignore-start
      if (kDebugMode) {
        debugPrint('MyLoggerCore.getLogStats() error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      // coverage:ignore-end
      return {
        'error': 'Failed to get log stats: $e',
        'className': _className,
        'fileLoggingReady': false,
        'initializationFailed': true,
      };
    }
  }

  @override
  bool resetFileLogging() {
    try {
      _fileOutput?.dispose();
      _fileOutput = null;
      _initializationFailed = false;
      _lastInitError = null;

      if (config.enableFileLogging && !kIsWeb) {
        _fileOutput = OmniFileOutput.createSync(
          maxLogFiles: config.maxLogFiles,
          maxFileSizeMB: config.maxFileSizeMB,
          enableCompression: config.enableCompression,
          logFilePrefix: config.logFilePrefix,
          logRetentionDays: config.logRetentionDays,
        );

        if (_fileOutput == null) {
          _initializationFailed = true;
          _lastInitError = 'Failed to recreate MyFileOutput instance';
          return false;
        }
      }

      return true;
    } catch (e) {
      _initializationFailed = true;
      _lastInitError = 'Exception during reset: $e';
      return false;
    }
  }

  /// Print beautiful log statistics with comprehensive diagnostic information
  ///
  /// This method ensures the logger is fully initialized before attempting
  /// to retrieve the stats, making it safe to call immediately after
  /// logger setup without waiting for the first log message.
  @override
  void printLogStats({required OmniLogger logger}) {
    try {
      // Ensure logger is initialized
      ensureInitialized();

      // Use a class-specific logger for printing stats
      final log = logger;

      final stats = logger.getLogStats();

      // Print beautiful header
      log.i('');
      log.i('╔═══════════════════════════════════════════════════════════');
      log.i('║                    📊 LOG STATISTICS                      ');
      log.i('╠═══════════════════════════════════════════════════════════');

      // Configuration Section
      log.i('║  ⚙️  CONFIGURATION                                        ');
      log.i('╠───────────────────────────────────────────────────────────');
      final config = stats['config'] as Map<String, dynamic>?;
      if (config != null && config.isNotEmpty) {
        config.forEach((key, value) {
          final formattedKey = _formatKey(key);
          final formattedValue = _formatValue(value);
          final line = '║    • $formattedKey: $formattedValue';
          // Truncate long lines to fit in the box
          final truncatedLine = line.length > 63
              ? '${line.substring(0, 60)}...'
              : line.padRight(63);
          log.i(truncatedLine);
        });
      } else {
        log.i('║    • No configuration data available                      ');
      }

      // Runtime State Section
      log.i('╠───────────────────────────────────────────────────────────');
      log.i('║  🚀 RUNTIME STATE                                         ');
      log.i('╠───────────────────────────────────────────────────────────');

      final fileLoggingReady = (stats['fileLoggingReady'] as bool?) ?? false;
      final initFailed = (stats['initializationFailed'] as bool?) ?? false;
      final className =
          stats['className'] as String; // Now guaranteed to be non-null

      log.i('║    • Class Name: ${className.padRight(42)}');
      log.i(
        '║    • File Logging Ready: ${_getStatusIcon(fileLoggingReady)} $fileLoggingReady'
            .padRight(63),
      );
      log.i(
        '║    • Initialization Failed: ${_getStatusIcon(!initFailed)} ${!initFailed ? 'No' : 'Yes'}'
            .padRight(63),
      );

      if (stats.containsKey('lastInitError')) {
        final error = stats['lastInitError'].toString();
        final truncatedError = error.length > 40
            ? '${error.substring(0, 40)}...'
            : error;
        log.i('║    • Last Init Error: ❌ $truncatedError'.padRight(63));
      }

      // File Information Section (if available)
      if (stats.containsKey('logDirectory') ||
          stats.containsKey('currentLogFile') ||
          stats.containsKey('totalLogFiles')) {
        log.i('╠───────────────────────────────────────────────────────────');
        log.i('║  📁 FILE INFORMATION                                      ');
        log.i('╠───────────────────────────────────────────────────────────');

        if (stats.containsKey('logDirectory')) {
          final logDir = stats['logDirectory']?.toString() ?? 'Not set';
          final sanitizedDir = OmniFileOutput.sanitizePath(logDir);
          log.i('║    • Directory: 📂 $sanitizedDir');
        }

        // Summary Information
        if (stats.containsKey('totalLogFiles')) {
          final totalFiles = stats['totalLogFiles'] ?? 0;
          log.i('║    • Total Log Files: 📊 $totalFiles'.padRight(63));
        }

        if (stats.containsKey('totalSizeMB')) {
          final totalSizeMB = stats['totalSizeMB'];
          final sizeIcon = _getSizeIcon(totalSizeMB);
          log.i('║    • Total Size: $sizeIcon $totalSizeMB MB'.padRight(63));
        }

        // Individual Log Files Section
        if (stats.containsKey('allLogFiles')) {
          final allFiles = stats['allLogFiles'] as List<Map<String, dynamic>>?;
          if (allFiles != null && allFiles.isNotEmpty) {
            log.i(
              '╠───────────────────────────────────────────────────────────',
            );
            log.i(
              '║  📄 ALL LOG FILES                                         ',
            );
            log.i(
              '╠───────────────────────────────────────────────────────────',
            );

            for (int i = 0; i < allFiles.length; i++) {
              final file = allFiles[i];
              final fileName = file['fileName']?.toString() ?? 'Unknown';
              final filePath = file['filePath']?.toString() ?? 'Unknown';
              final sizeMB = file['sizeMB'] ?? 0.0;
              final sizeIcon = _getSizeIcon(sizeMB);
              final lastModified =
                  file['lastModified']?.toString() ?? 'Unknown';
              final isCurrent = file['isCurrent'] as bool? ?? false;

              // File header with index
              final fileHeader = isCurrent
                  ? '║  📄 File ${i + 1} (CURRENT): $fileName'
                  : '║  📄 File ${i + 1}: $fileName';
              log.i(fileHeader);

              // Full file path (clickable)
              log.i('║    • Path: ${OmniFileOutput.sanitizePath(filePath)}');

              // File size with icon
              log.i('║    • Size: $sizeIcon $sizeMB MB'.padRight(63));

              // Last modified
              log.i('║    • Modified: $lastModified');

              // Add separator between files (except for last file)
              if (i < allFiles.length - 1) {
                log.i(
                  '║  ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈',
                );
              }
            }
          }
        } else {
          // Fallback to individual file display if allLogFiles not available
          if (stats.containsKey('currentLogFile')) {
            final currentFile = stats['currentLogFile']?.toString() ?? 'None';
            // Don't truncate file paths - display full path for tapping
            log.i('║    • Current File: 📄 $currentFile');
          }

          if (stats.containsKey('currentFileSizeMB')) {
            final sizeMB = stats['currentFileSizeMB'];
            final sizeIcon = _getSizeIcon(sizeMB);
            log.i(
              '║    • Current File Size: $sizeIcon $sizeMB MB'.padRight(63),
            );
          }

          if (stats.containsKey('oldestLogFile')) {
            final oldestFile = stats['oldestLogFile']?.toString() ?? 'None';
            // Don't truncate file paths - display full path for tapping
            log.i('║    • Oldest File: 🗓️ $oldestFile');
          }

          if (stats.containsKey('newestLogFile')) {
            final newestFile = stats['newestLogFile']?.toString() ?? 'None';
            // Don't truncate file paths - display full path for tapping
            log.i('║    • Newest File: 🆕 $newestFile');
          }
        }
      }

      // Activity Section (if available)
      if (stats.containsKey('writesSinceLastCheck') ||
          stats.containsKey('lastCleanupTime')) {
        log.i('╠───────────────────────────────────────────────────────────');
        log.i('║  📈 ACTIVITY                                               ');
        log.i('╠───────────────────────────────────────────────────────────');

        if (stats.containsKey('writesSinceLastCheck')) {
          final writes = stats['writesSinceLastCheck'] ?? 0;
          log.i('║    • Writes Since Last Check: ✍️ $writes'.padRight(63));
        }

        if (stats.containsKey('lastCleanupTime')) {
          final cleanupTime = stats['lastCleanupTime']?.toString() ?? 'Never';
          final truncatedTime = cleanupTime.length > 35
              ? '${cleanupTime.substring(0, 35)}...'
              : cleanupTime;
          log.i('║    • Last Cleanup Time: 🧹 $truncatedTime'.padRight(63));
        }
      }

      // Footer
      log.i('╚═══════════════════════════════════════════════════════════');
      log.i('');
    } catch (e, stackTrace) {
      // Enhanced error handling
      try {
        // Try to use the current logger first
        final errorLog = getLogger(className: 'LogStatsError');
        errorLog.e(
          '❌ Error printing log statistics: $e',
          error: e,
          stackTrace: stackTrace,
        );
      } catch (secondaryError) {
        // Fallback to debug print if logger fails completely
        // coverage:ignore-start
        if (kDebugMode) {
          debugPrint('❌ Error printing log statistics: $e');
          debugPrint('Secondary error in error handling: $secondaryError');
          debugPrint('Stack trace: $stackTrace');
        }
        // coverage:ignore-end
      }
    }
  }

  /// Helper method to format configuration keys for display
  String _formatKey(String key) {
    const overrides = {
      'maxFileSizeMB': 'Max File Size MB',
      'logRetentionDays': 'Log Retention Days',
      'logFilePrefix': 'Log File Prefix',
      // Add more as needed
    };

    if (overrides.containsKey(key)) return overrides[key]!;

    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ')
        .trim();
  }

  /// Helper method to format values for display
  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value ? '✅ true' : '❌ false';
    if (value is String) return '"$value"';
    if (value is num) return value.toString();
    if (value is List) return '[${value.length} items]';
    if (value is Map) return '{${value.length} entries}';
    return value.toString();
  }

  /// Helper method to get status icons
  String _getStatusIcon(bool status) {
    return status ? '✅' : '❌';
  }

  /// Helper method to get size icons based on file size
  String _getSizeIcon(dynamic sizeMB) {
    if (sizeMB == null) return '📊';

    final size = sizeMB is num ? sizeMB.toDouble() : 0.0;

    if (size == 0) return '📊';
    if (size < 1) return '🟢'; // Less than 1MB - Green
    if (size < 10) return '🟡'; // 1-10MB - Yellow
    if (size < 50) return '🟠'; // 10-50MB - Orange
    return '🔴'; // 50MB+ - Red
  }

  @override
  void dispose() {
    _fileOutput?.dispose();
    _fileOutput = null;
    _internalLogger = null;
  }

  // Clean all log files - useful for development/testing
  @override
  bool cleanAllLogs() {
    try {
      // Clean through the file output if available
      // This will clean all log files and reset
      if (_fileOutput != null) {
        final success = _fileOutput!.cleanAllLogFilesAndReset();

        if (success) {
          // Reset the internal state
          _initializationFailed = false;
          _lastInitError = null;

          // Log the cleanup
          final cleanupLogger = getLogger(className: 'LogCleaner');
          cleanupLogger.i('🧹 All log files cleaned successfully');

          return true;
        } else {
          final cleanupLogger = getLogger(className: 'LogCleaner');
          cleanupLogger.w('⚠️ Failed to clean some log files');
          return false;
        }
      } else {
        // coverage:ignore-start
        // No file output available - nothing to clean
        if (kDebugMode) {
          debugPrint('MyLoggerCore: No file output available for cleaning');
        }
        // coverage:ignore-end
        return true; // Consider this success since there's nothing to clean
      }
    } catch (e, stackTrace) {
      // coverage:ignore-start
      if (kDebugMode) {
        debugPrint('MyLoggerCore: Error cleaning logs: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      // coverage:ignore-end
      return false;
    }
  }
}
