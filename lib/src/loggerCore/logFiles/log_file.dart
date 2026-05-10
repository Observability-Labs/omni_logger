// import 'package:get_it/get_it.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:omni_logger/src/loggerManager/my_log_manager.dart';
import 'package:omni_logger/src/loggerManager/support/my_log_directory.dart';
import 'package:omni_logger/src/loggerCore/logFiles/support/log_build_and_stats.dart';
import 'package:path/path.dart' as path;

enum OmniLogType {
  general('general', false);

  const OmniLogType(this.typeName, this.shouldFlush);
  final String typeName;
  final bool shouldFlush;
}

class OmniFileOutput extends LogOutput {
  final int maxLogFiles;
  final int maxFileSizeMB; // Keep as MB for consistency
  final bool enableCompression;
  final String logFilePrefix;
  final int logRetentionDays;

  File? _currentLogFile;
  String? _currentDate;
  final String _logDirectory;
  int _currentFileSizeInBytes = 0; // Always in bytes internally
  bool _isInitialized = false;
  DateTime? _lastCleanupTime;
  int _writesSinceLastCheck = 0;
  static const int _checksPerCleanup = 100;

  // Private constructor
  OmniFileOutput._(
    this._logDirectory,
    this.maxLogFiles,
    this.maxFileSizeMB,
    this.enableCompression,
    this.logFilePrefix,
    this.logRetentionDays,
  );

  /// Factory constructor with comprehensive error handling
  static OmniFileOutput? createSync({
    int maxLogFiles = 7,
    int maxFileSizeMB = 10,
    bool enableCompression = false,
    String logFilePrefix = 'app',
    String? customLogDirectory,
    int logRetentionDays = 1,
  }) {
    try {
      final logDir =
          customLogDirectory ?? MyLogDirectoryManage.getDefaultLogDirectory();
      if (logDir == null) {
        // coverage:ignore-start
        _debugPrint('OmniFileOutput: Unable to determine log directory');
        // coverage:ignore-end
        return null;
      }

      final instance = OmniFileOutput._(
        logDir,
        maxLogFiles,
        maxFileSizeMB,
        enableCompression,
        logFilePrefix,
        logRetentionDays,
      );

      if (instance._initializeSync()) {
        return instance;
      } else {
        // coverage:ignore-start
        _debugPrint('OmniFileOutput: Failed to initialize');
        // coverage:ignore-end
        return null;
      }
    } catch (e, stackTrace) {
      // coverage:ignore-start
      _debugPrint('OmniFileOutput: Creation failed: $e');
      _debugPrint('Stack trace: $stackTrace');
      // coverage:ignore-end
      return null;
    }
  }

  /// Initialize the logging system
  bool _initializeSync() {
    try {
      final dir = Directory(_logDirectory);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      _initializeOrRotataLogFileSync();
      _performInitialCleanup();

      _isInitialized = true;
      // coverage:ignore-start
      _debugPrint('OmniFileOutput: Initialized successfully at $_logDirectory');
      // coverage:ignore-end
      return true;
    } catch (e, stackTrace) {
      // coverage:ignore-start
      _debugPrint('OmniFileOutput: Initialization failed: $e');
      _debugPrint('Stack trace: $stackTrace');
      // coverage:ignore-end
      return false;
    }
  }

  void _performInitialCleanup() {
    try {
      MyLogManager.cleanOldLogsSync(
        _logDirectory,
        logFilePrefix,
        maxLogFiles,
        logRetentionDays,
        enableCompression,
      );
      _lastCleanupTime = DateTime.now();
    } catch (e) {
      // coverage:ignore-start
      _debugPrint('OmniFileOutput: Error during initial cleanup: $e');
      // coverage:ignore-end
    }
  }

  // Getters
  String? get currentLogFilePath {
    final path = _currentLogFile?.path;
    return path == null ? null : sanitizePath(path);
  }

  String get logDirectory => sanitizePath(_logDirectory);

  bool get isReady => _isInitialized && _currentLogFile != null;
  int get currentLogFileSize => _currentFileSizeInBytes;

  void _initializeOrRotataLogFileSync() {
    try {
      final logFileInfo = MyLogManager.initializeOrRotateLogFile(
        logDirectory: Directory(_logDirectory),
        logFilePrefix: logFilePrefix,
        logType: OmniLogType.general,
        maxFileSizeMB: maxFileSizeMB,
        currentDate: _currentDate,
        currentFile: _currentLogFile,
      );

      // Make sure to update your class fields from the returned info:
      if (logFileInfo.file == null) {
        // coverage:ignore-start
        _debugPrint(
          'OmniFileOutput: Failed to initialize log file: ${logFileInfo.error}',
        );
        // coverage:ignore-end
        return;
      }

      _currentLogFile = logFileInfo.file;
      _currentDate = logFileInfo.currentDate;
      _currentFileSizeInBytes = logFileInfo.currentSize;

      _writeLogHeader();

      // coverage:ignore-start
      _debugPrint(
        'OmniFileOutput: Log file initialized: ${_currentLogFile!.path}',
      );
      // coverage:ignore-end
    } catch (e) {
      // coverage:ignore-start
      _debugPrint('OmniFileOutput: Error initializing log file: $e');
      // coverage:ignore-end
    }
  }

  /// Write log file header with complete information
  void _writeLogHeader() {
    try {
      if (_currentLogFile == null) return;

      int currentSize = 0;
      if (_currentLogFile!.existsSync()) {
        currentSize = _currentLogFile!.lengthSync();
      }

      MyLogManager.writeLogHeader(
        logFile: _currentLogFile!,
        logType: OmniLogType.general,
        logFilePrefix: logFilePrefix,
        maxFileSizeMB: maxFileSizeMB,
        maxLogFiles: maxLogFiles,
        logRetentionDays: logRetentionDays,
        currentFileSizeBytes: currentSize,
      );

      // Update cached file size after writing header
      if (_currentLogFile!.existsSync()) {
        _currentFileSizeInBytes = _currentLogFile!.lengthSync();
      }
    } catch (e) {
      // coverage:ignore-start
      _debugPrint('OmniFileOutput: Error writing log header: $e');
      // coverage:ignore-end
    }
  }

  void _performPeriodicCleanup() {
    try {
      final now = DateTime.now();

      if (_lastCleanupTime != null &&
          now.difference(_lastCleanupTime!).inHours < 1) {
        return;
      }

      MyLogManager.cleanOldLogsSync(
        _logDirectory,
        logFilePrefix,
        maxLogFiles,
        logRetentionDays,
        enableCompression,
      );
      _lastCleanupTime = now;
    } catch (e) {
      // coverage:ignore-start
      _debugPrint('OmniFileOutput: Error during periodic cleanup: $e');
      // coverage:ignore-end
    }
  }

  /// Handles writing log entries to the current log file.
  ///
  /// - Checks if log rotation is needed based on file size or date changes before writing.
  /// - Writes the log entry to the file and updates the cached current file size.
  /// - Periodically triggers cleanup of old log files to manage disk space.
  /// - Handles errors by attempting to reinitialize the logging system.
  ///
  /// This method is called whenever a new log entry is emitted.
  @override
  void output(OutputEvent event) {
    if (!_isInitialized || _logDirectory.isEmpty) return;

    try {
      _writesSinceLastCheck++;

      // Combine log lines into a single string entry with a newline at the end
      final logEntry = '${event.lines.join('\n')}\n';
      final entryBytes = utf8.encode(logEntry).length;

      // Check if log rotation is needed BEFORE writing:
      // - No current log file (first write or after rotation)
      // - Adding this entry would exceed max file size
      // - Every 10 writes, check if the date changed to rotate daily logs
      final maxFileSizeBytes = maxFileSizeMB * 1024 * 1024;
      if (_currentLogFile == null ||
          _currentFileSizeInBytes + entryBytes > maxFileSizeBytes ||
          (_writesSinceLastCheck % 10 == 0 &&
              _currentDate != MyLogDirectoryManage.getTodayString())) {
        _initializeOrRotataLogFileSync(); // rotate or initialize new log file
      }

      if (_currentLogFile == null) {
        // coverage:ignore-start
        _debugPrint('OmniFileOutput: No current log file available');
        // coverage:ignore-end
        return;
      }

      // Append the log entry to the file and update the cached file size
      _currentLogFile!.writeAsStringSync(logEntry, mode: FileMode.append);
      _currentFileSizeInBytes += entryBytes;

      // Perform periodic cleanup after a set number of writes
      if (_writesSinceLastCheck >= _checksPerCleanup) {
        _performPeriodicCleanup();
        _writesSinceLastCheck = 0;
      }
    } catch (e, stackTrace) {
      // coverage:ignore-start
      _debugPrint('OmniFileOutput: Error writing to log file: $e');
      _debugPrint('Stack trace: $stackTrace');
      // coverage:ignore-end

      // On error, try to reinitialize the logger to recover
      try {
        _isInitialized = false;
        _initializeSync();
      } catch (reinitError) {
        // coverage:ignore-start
        _debugPrint('OmniFileOutput: Failed to reinitialize: $reinitError');
        // coverage:ignore-end
      }
    }
  }

  // All User Info MUST be removed from file and dir path
  // in release mode
  static String sanitizePath(String fullPath) {
    if (kReleaseMode) {
      // Just the file name in production (no use info)
      return path.basename(fullPath);
    } else {
      // Full path in debug or profile
      return fullPath;
    }
  }

  /// Get log statistics
  Map<String, dynamic> getLogStats() {
    try {
      // Start with base stats from MyLogFileBuildAndStats
      final baseStats = MyLogFileBuildAndStats.getLogStats(
        _logDirectory,
        logFilePrefix,
      );

      // Add detailed file information
      final Directory logDir = Directory(_logDirectory);
      if (logDir.existsSync()) {
        final logFiles = logDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.log'))
            .toList();

        // Sort files by modification time (newest first)
        logFiles.sort(
          (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
        );

        // Calculate total size and build allLogFiles array
        double totalSizeMB = 0.0;
        final List<Map<String, dynamic>> allLogFiles = [];

        for (int i = 0; i < logFiles.length; i++) {
          final file = logFiles[i];
          final fileName = path.basename(file.path);
          final filePath = file.path;
          final sizeBytes = file.lengthSync();
          final sizeMB = sizeBytes / (1024 * 1024);
          final lastModified = file.lastModifiedSync().toIso8601String();
          final isCurrent = filePath == currentLogFilePath;

          totalSizeMB += sizeMB;

          // Add to allLogFiles array
          allLogFiles.add({
            'fileName': fileName,
            'filePath': filePath,
            'sizeMB': double.parse(sizeMB.toStringAsFixed(2)),
            'sizeBytes': sizeBytes,
            'lastModified': lastModified,
            'isCurrent': isCurrent,
          });
        }

        // Override/add the detailed information
        baseStats['totalLogFiles'] = logFiles.length;
        baseStats['totalSizeMB'] = double.parse(totalSizeMB.toStringAsFixed(2));
        baseStats['allLogFiles'] =
            allLogFiles; // This is the key missing piece!

        // Oldest and newest file timestamps
        if (logFiles.isNotEmpty) {
          baseStats['newestLogFile'] = logFiles.first
              .lastModifiedSync()
              .toIso8601String();
          baseStats['oldestLogFile'] = logFiles.last
              .lastModifiedSync()
              .toIso8601String();
        }
      }

      // Add OmniFileOutput specific stats
      baseStats.addAll({
        'currentLogFile': currentLogFilePath,
        'currentFileSize': _currentFileSizeInBytes,
        'currentFileSizeMB': (_currentFileSizeInBytes / (1024 * 1024))
            .toStringAsFixed(2),
        'maxFiles': maxLogFiles,
        'maxFileSizeMB': maxFileSizeMB,
        'logRetentionDays': logRetentionDays,
        'isReady': isReady,
        'writesSinceLastCheck': _writesSinceLastCheck,
        'lastCleanupTime': _lastCleanupTime?.toIso8601String(),
        'logDirectory': _logDirectory,
      });

      return baseStats;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('OmniFileOutput.getLogStats() error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return {'error': 'Failed to get log stats: $e'};
    }
  }

  // This will delete all AppLog files which is stored in our custom directory:
  // /Users/YourUserName/Library/Logs/MyApp
  bool cleanAllLogFilesAndReset() {
    try {
      final dir = Directory(_logDirectory);
      if (!dir.existsSync()) {
        _debugPrint(
          'OmniFileOutput: Log directory does not exist: $_logDirectory',
        );
        return false;
      }

      // Get ALL .log files in your app's dedicated directory
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.log'))
          .toList();

      _debugPrint('OmniFileOutput: Found ${files.length} total log files');

      if (files.isEmpty) {
        _debugPrint('OmniFileOutput: No log files found to clean');
        return true;
      }

      var deletedCount = 0;
      var failedCount = 0;

      for (final file in files) {
        try {
          final fileName = path.basename(file.path);
          file.deleteSync();
          deletedCount++;
          _debugPrint('OmniFileOutput: Deleted $fileName');
        } catch (e) {
          failedCount++;
          _debugPrint('OmniFileOutput: Error deleting ${file.path}: $e');
        }
      }

      // Reset state
      _currentLogFile = null;
      _currentDate = null;
      _currentFileSizeInBytes = 0;
      _writesSinceLastCheck = 0;
      _lastCleanupTime = DateTime.now();

      _debugPrint(
        'OmniFileOutput: Cleaned $deletedCount log files, $failedCount failed',
      );

      // Reinitialize
      if (deletedCount > 0) {
        _initializeOrRotataLogFileSync();
      }

      return failedCount == 0;
    } catch (e) {
      _debugPrint('OmniFileOutput: Error cleaning all log files: $e');
      return false;
    }
  }

  void dispose() {
    try {
      if (_isInitialized) {
        _performPeriodicCleanup();
      }

      _currentLogFile = null;
      _currentDate = null;
      _currentFileSizeInBytes = 0;
      _isInitialized = false;
      _writesSinceLastCheck = 0;
      _lastCleanupTime = null;

      // coverage:ignore-start
      _debugPrint('OmniFileOutput: Disposed successfully');
      // coverage:ignore-end
    } catch (e) {
      // coverage:ignore-start
      _debugPrint('OmniFileOutput: Error during disposal: $e');
      // coverage:ignore-end
    }
  }

  static void _debugPrint(String message) {
    if (kDebugMode) {
      print(message);
    }
  }
}
