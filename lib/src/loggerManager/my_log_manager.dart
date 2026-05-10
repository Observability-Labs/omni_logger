import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:omni_logger/omni_logger.dart';
import 'package:omni_logger/src/loggerCore/logFiles/log_file.dart';
import 'package:omni_logger/src/loggerManager/support/file_clean_helpers.dart';
import 'package:omni_logger/src/loggerManager/support/my_isolate_helpers.dart';
import 'package:omni_logger/src/loggerManager/support/my_log_directory.dart';
import 'package:omni_logger/src/loggerManager/models/log_info.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';

/// About: void writeLogHeader()
/// Writes the log file header, including size and rotation metadata.
///
/// 🟡 This function is called **only once** per log file lifecycle:
/// - At initialization of a new log file
/// - Or when an existing file is rotated due to size or date constraints
///
/// 🔁 It does **not** update dynamically with each log entry.
/// Instead, it captures a snapshot of the file state at the time of initialization.
///
/// 📌 `currentFileSizeBytes` is passed in during setup using
/// `_currentLogFile!.lengthSync()`. After that point, size is tracked
/// **in-memory** using `_currentFileSizeInBytes`, which increases
/// with each new log entry.
///
/// ⚠️ As a result, the size displayed in the header can become outdated
/// as the file grows. It reflects the size **only at the time of creation**.
///
/// 📎 For example:
/// If a new log file is created and the header is written when the file size is 0 bytes,
/// the header will always show:
///   Current Used: 0.00MB (0 bytes)
/// even if the file later grows to several MBs through appended log entries.
///
/// ➕ Only actual log content is appended after this point —
/// the header remains unchanged until a new file is initialized or rotated.
///
/// 🧹 When the file reaches the `maxFileSizeMB` threshold, the logger performs:
/// - **File rotation**: A new file is created
/// - **New header is written**: with updated current size (usually 0 bytes initially)
/// - **Internal counters reset**, and logging continues into the new file
///
/// 🗑️ Old log files are **not deleted immediately** upon rotation.
/// Instead, a scheduled cleanup (based on `maxLogFiles` and/or `logRetentionDays`)
/// removes outdated logs during periodic checks.
///
/// 🔄 This ensures each log file starts fresh with an accurate header at the time of creation,
/// while allowing the system to manage disk usage through rotation and retention policies.

class MyLogManager {
  /// Initializes or rotates the log file based on the following conditions:
  /// - If `currentFile` is null or does not exist, a new log file is created.
  /// - If the date has changed since `currentDate`, a new daily log file is created.
  /// - If the current log file size exceeds `maxFileSizeMB`, a new file is created for size-based rotation.
  ///
  /// Returns a `LogFileInfo` containing the current or newly created log file, its date, and size.
  /// In case of failure, returns `LogFileInfo` with error details.
  static LogFileInfo initializeOrRotateLogFile({
    required Directory logDirectory,
    required String logFilePrefix,
    required OmniLogType logType,
    required int maxFileSizeMB,
    File? currentFile,
    String? currentDate,
  }) {
    try {
      // Validate and cap maxFileSizeMB to prevent overflow
      final safeMB = MyLogManageFileSizeHelpers.validateMaxFileSize(
        maxFileSizeMB,
      );
      final today = MyLogDirectoryManage.getTodayString();
      final maxFileSizeBytes = MyLogManageFileSizeHelpers.calculateMaxFileSize(
        safeMB,
      );

      // Get current file size safely
      int currentFileSizeInBytes = MyLogManageFileSizeHelpers.getFileSizeSafely(
        currentFile,
      );
      bool fileExists = currentFile != null && currentFileSizeInBytes > 0;

      // Determine if rotation is needed
      final shouldRotate =
          currentDate != today ||
          !fileExists ||
          currentFileSizeInBytes >= maxFileSizeBytes;

      if (shouldRotate) {
        return _rotateLogFile(
          logDirectory: logDirectory,
          logFilePrefix: logFilePrefix,
          logType: logType,
          today: today,
          sizeBasedRotation: currentFileSizeInBytes >= maxFileSizeBytes,
        );
      }

      // No rotation needed, return current log file info
      return LogFileInfo(
        file: currentFile,
        currentDate: currentDate ?? today,
        currentSize: currentFileSizeInBytes,
      );
    } catch (e) {
      // coverage:ignore-start
      debugPrint(
        'MyLogManager: Critical error in initializeOrRotateLogFile: $e',
      );
      // coverage:ignore-end
      return LogFileInfo(
        file: null,
        currentDate: MyLogDirectoryManage.getTodayString(),
        currentSize: 0,
        error: 'Failed to initialize: $e',
      );
    }
  }

  /// Write enhanced log file header with device and size information
  static Future<bool> writeLogHeader({
    required File logFile,
    required OmniLogType logType,
    required String logFilePrefix,
    required int maxFileSizeMB,
    required int maxLogFiles,
    required int logRetentionDays,
    int currentFileSizeBytes = 0,
    bool includeDeviceInfo = true,
  }) async {
    try {
      // Validate inputs
      final safeMB = MyLogManageFileSizeHelpers.validateMaxFileSize(
        maxFileSizeMB,
      );
      final maxFileSizeBytes = MyLogManageFileSizeHelpers.calculateMaxFileSize(
        safeMB,
      );

      // Calculate detailed size breakdown for logging
      final remainingBytes = (maxFileSizeBytes - currentFileSizeBytes).clamp(
        0,
        maxFileSizeBytes,
      );
      final currentSizeMB = (currentFileSizeBytes / (1024 * 1024));
      final remainingSizeMB = (remainingBytes / (1024 * 1024));
      final usagePercent = maxFileSizeBytes > 0
          ? (currentFileSizeBytes / maxFileSizeBytes * 100)
          : 0.0;

      // Get device info if requested
      String deviceInfoSection = '';
      if (includeDeviceInfo) {
        deviceInfoSection = await _buildDeviceInfoSection();
      }

      // Construct the formatted log header
      final header =
          '''
=== OMNILOGGER ${logType.typeName.toUpperCase()} LOG STARTED ===
Timestamp: ${DateTime.now().toIso8601String()}
Application: $logFilePrefix
Dart Version: ${Platform.version}
Isolate: ${MyLogIsolateHelpers.formatIsolateInfo()}
$deviceInfoSection

=== FILE SIZE INFORMATION ===
Max File Size: ${safeMB}MB (${MyLogManageFileSizeHelpers.formatBytes(maxFileSizeBytes)} bytes)
Current Used: ${currentSizeMB.toStringAsFixed(2)}MB (${MyLogManageFileSizeHelpers.formatBytes(currentFileSizeBytes)} bytes)
Remaining: ${remainingSizeMB.toStringAsFixed(2)}MB (${MyLogManageFileSizeHelpers.formatBytes(remainingBytes)} bytes)
Usage: ${usagePercent.toStringAsFixed(1)}%

=== ROTATION SETTINGS ===
Max Files: $maxLogFiles
Retention Days: $logRetentionDays

''';

      // Write header to the log file safely
      return MyLogManageFileSizeHelpers.writeLogSafely(
        logFile,
        header,
        FileMode.append,
      );
    } catch (e) {
      // coverage:ignore-start
      debugPrint('MyLogManager: Error writing log header: $e');
      // coverage:ignore-end
      return false;
    }
  }

  /// Build privacy-focused device information for debugging
  /// Collects only essential technical data needed for debugging
  static Future<String> _buildDeviceInfoSection() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('\n=== DEVICE INFORMATION ===');

      // Basic platform info - always available
      buffer.writeln(
        'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      );

      // Flutter build mode - critical for debugging
      if (kDebugMode) {
        buffer.writeln('Build Mode: Debug');
      } else if (kProfileMode) {
        buffer.writeln('Build Mode: Profile');
      } else {
        buffer.writeln('Build Mode: Release');
      }

      // coverage:ignore-start
      // Get platform-specific essential info
      try {
        final deviceInfo = DeviceInfoPlugin();

        if (Platform.isAndroid) {
          final info = await deviceInfo.androidInfo;
          buffer.writeln('API Level: ${info.version.sdkInt}');
          buffer.writeln('Architecture: ${info.supportedAbis.first}');
          buffer.writeln('Physical Device: ${info.isPhysicalDevice}');
        } else if (Platform.isIOS) {
          final info = await deviceInfo.iosInfo;
          buffer.writeln('Architecture: ${info.utsname.machine}');
          buffer.writeln('Physical Device: ${info.isPhysicalDevice}');
        } else if (Platform.isWindows) {
          final info = await deviceInfo.windowsInfo;
          buffer.writeln('Build: ${info.buildNumber}');
        } else if (Platform.isMacOS) {
          final info = await deviceInfo.macOsInfo;
          // Model is technical (like "MacBookPro18,1"), not personal
          buffer.writeln('Model: ${info.model}');
        } else if (Platform.isLinux) {
          final info = await deviceInfo.linuxInfo;
          buffer.writeln('Distribution: ${info.name}');
        }
      } catch (e) {
        buffer.writeln(
          'Platform Info: Limited (${e.toString().split(':').first})',
        );
      }
      // coverage:ignore-end

      return buffer.toString();
    } catch (e) {
      return '\n=== DEVICE INFORMATION ===\nError: Failed to retrieve device info\n';
    }
  }

  static LogFileInfo _rotateLogFile({
    required Directory logDirectory,
    required String logFilePrefix,
    required OmniLogType logType,
    required String today,
    bool sizeBasedRotation = false,
  }) {
    try {
      final fileName = MyLogDirectoryManage.createLogFileName(
        logFilePrefix: logFilePrefix,
        logType: logType,
        date: today,
        timestamp: sizeBasedRotation
            ? MyLogDirectoryManage.getTimestampString()
            : null,
      );

      final filePath = path.join(logDirectory.path, fileName);
      final newFile = MyLogManageFileSizeHelpers.createLogFileSafely(filePath);

      if (newFile == null) {
        return LogFileInfo(
          file: null,
          currentDate: today,
          currentSize: 0,
          error: 'Failed to create log file: $filePath',
        );
      }

      return LogFileInfo(
        file: newFile,
        currentDate: today,
        currentSize: MyLogManageFileSizeHelpers.getFileSizeSafely(newFile),
      );
    } catch (e) {
      // coverage:ignore-start
      debugPrint('MyLogManager: Error rotating log file: $e');
      // coverage:ignore-end
      return LogFileInfo(
        file: null,
        currentDate: today,
        currentSize: 0,
        error: 'Failed to rotate: $e',
      );
    }
  }

  static int writeLogEntry({
    required File logFile,
    required List<String> lines,
    required OmniLogLevel level,
    OmniLogType logType = OmniLogType.general,
    bool includeTimestamp = true,
    bool flush = false,
  }) {
    if (lines.isEmpty) return 0;

    try {
      final timestamp = includeTimestamp
          ? DateTime.now().toIso8601String()
          : '';
      final isErrorOrHigher =
          level == OmniLogLevel.error ||
          level == OmniLogLevel.fatal ||
          level == OmniLogLevel.off;

      String logContent;
      if (isErrorOrHigher) {
        //if (logType == MyLogType.crash && isErrorOrHigher) {
        logContent = [
          '\n=== ${level.name.toUpperCase()} LOGGED AT $timestamp ===',
          ...lines,
          '=== END LOG ENTRY ===\n',
        ].join('\n');
      } else {
        final prefix = includeTimestamp ? '[$timestamp] ' : '';
        logContent = '$prefix${lines.join('\n')}\n';
      }

      final success = MyLogManageFileSizeHelpers.writeLogSafely(
        logFile,
        logContent,
        FileMode.append,
      );
      return success ? utf8.encode(logContent).length : 0;
    } catch (e) {
      // coverage:ignore-start
      debugPrint('MyLogManager: Error writing log entry: $e');
      // coverage:ignore-end
      return 0;
    }
  }

  /// Cleans old log files in the specified directory based on retention policy.
  ///
  /// This method deletes log files that:
  /// - Are older than [logRetentionDays] days, or
  /// - Exceed the maximum number of log files specified by [maxLogFiles].
  ///
  /// Optionally compresses log files before deletion if [enableCompression] is true.
  ///
  /// Parameters:
  /// - [logDirectory]: Path to the directory containing log files.
  /// - [logFilePrefix]: Prefix used to identify relevant log files.
  /// - [maxLogFiles]: Maximum number of log files to keep.
  /// - [logRetentionDays]: Number of days to retain log files.
  /// - [enableCompression]: If true, compress files before deleting.
  ///
  /// Exceptions are caught and logged via debugPrint, but do not throw.
  /// Cleans old log files in the specified directory based on retention policy.
  /// - Deletes logs older than [logRetentionDays].
  /// - Limits total number of retained logs to [maxLogFiles].
  /// - Optionally compresses logs before deletion.
  /// Returns the number of files cleaned up.

  static int cleanOldLogsSync(
    String logDirectory,
    String logFilePrefix,
    int maxLogFiles,
    int logRetentionDays,
    bool enableCompression,
  ) {
    try {
      final dir = Directory(logDirectory);
      if (!dir.existsSync()) {
        // coverage:ignore-start
        // debugPrint('MyLogManager: Log directory does not exist: $logDirectory');
        // coverage:ignore-end
        return 0;
      }

      // Validate parameters
      if (maxLogFiles < 1) {
        // coverage:ignore-start
        // debugPrint(
        //     'MyLogManager: Invalid maxLogFiles ($maxLogFiles), must be >= 1');
        // coverage:ignore-end
        return 0;
      }

      if (logRetentionDays < 0) {
        // coverage:ignore-start
        // debugPrint(
        //     'MyLogManager: Invalid logRetentionDays ($logRetentionDays), must be >= 0');
        // coverage:ignore-end
        return 0;
      }

      // Get all log files sorted by modification date (most recent first)
      final allLogFiles = MyLogManageFileSizeHelpers.getSortedLogFiles(
        dir,
        logFilePrefix,
      );

      if (allLogFiles.isEmpty) {
        // coverage:ignore-start
        // debugPrint(
        //     'MyLogManager: No log files found with prefix: $logFilePrefix');
        // coverage:ignore-end
        return 0;
      }

      final filesToDelete = <File>[];

      // Step 1: Find files older than retention period
      if (logRetentionDays > 0) {
        final oldFiles = MyLogManageFileSizeHelpers.findFilesOlderThan(
          allLogFiles,
          logRetentionDays,
        );
        filesToDelete.addAll(oldFiles);

        if (oldFiles.isNotEmpty) {
          // coverage:ignore-start
          // debugPrint(
          //     'MyLogManager: Found ${oldFiles.length} files older than $logRetentionDays days');
          // coverage:ignore-end
        }
      }

      // Step 2: Find files exceeding max count (excluding already marked files)
      final excessFiles = MyLogManageFileSizeHelpers.findFilesExceedingMax(
        allLogFiles,
        filesToDelete,
        maxLogFiles,
      );
      filesToDelete.addAll(excessFiles);

      if (excessFiles.isNotEmpty) {
        // coverage:ignore-start
        // debugPrint(
        //     'MyLogManager: Found ${excessFiles.length} files exceeding max count of $maxLogFiles');
        // coverage:ignore-end
      }

      // Step 3: Delete the files
      if (filesToDelete.isNotEmpty) {
        MyLogManageFileSizeHelpers.deleteFiles(
          filesToDelete,
          enableCompression,
        );
        // coverage:ignore-start
        // debugPrint(
        //     'MyLogManager: Successfully cleaned ${filesToDelete.length} log files');
        // coverage:ignore-end
        return filesToDelete.length;
      } else {
        // coverage:ignore-start
        //debugPrint('MyLogManager: No log files need cleaning');
        // coverage:ignore-end
        return 0;
      }
    } catch (e) {
      // coverage:ignore-start
      debugPrint('MyLogManager: Error during log cleanup: $e');
      // coverage:ignore-end
      return 0;
    }
  }
}



  // /// Performs a comprehensive health check on the logging system
  // static Map<String, dynamic> performHealthCheck({
  //   required String logDirectory,
  //   required String logFilePrefix,
  //   File? currentLogFile,
  // }) {
  //   final healthCheck = <String, dynamic>{
  //     'timestamp': DateTime.now().toIso8601String(),
  //     'status': 'healthy',
  //     'issues': <String>[],
  //     'metrics': <String, dynamic>{},
  //   };

  //   try {
  //     // Check directory accessibility
  //     final dir = Directory(logDirectory);
  //     if (!dir.existsSync()) {
  //       healthCheck['issues']
  //           .add('Log directory does not exist: $logDirectory');
  //       healthCheck['status'] = 'critical';
  //     } else {
  //       // Check directory permissions
  //       try {
  //         final testFile = File(path.join(logDirectory, '.health_check_temp'));
  //         testFile.writeAsStringSync('test', flush: true);
  //         testFile.deleteSync();
  //       } catch (e) {
  //         healthCheck['issues'].add('Cannot write to log directory: $e');
  //         healthCheck['status'] = 'critical';
  //       }
  //     }

  //     // Check current log file
  //     if (currentLogFile != null) {
  //       final fileSize =
  //           MyLogManageFileSizeHelpers.getFileSizeSafely(currentLogFile);
  //       healthCheck['metrics']['current_log_size_bytes'] = fileSize;
  //       healthCheck['metrics']['current_log_size_mb'] =
  //           (fileSize / (1024 * 1024)).toStringAsFixed(2);

  //       if (fileSize == 0 && currentLogFile.existsSync()) {
  //         healthCheck['issues'].add('Current log file exists but is empty');
  //         if (healthCheck['status'] == 'healthy') {
  //           healthCheck['status'] = 'warning';
  //         }
  //       }
  //     }

  //     // Count total log files
  //     if (dir.existsSync()) {
  //       final logFiles =
  //           MyLogManageFileSizeHelpers.getSortedLogFiles(dir, logFilePrefix);
  //       healthCheck['metrics']['total_log_files'] = logFiles.length;
  //       healthCheck['metrics']['total_log_size_bytes'] = logFiles.fold<int>(
  //           0,
  //           (sum, file) =>
  //               sum + MyLogManageFileSizeHelpers.getFileSizeSafely(file));
  //     }
  //   } catch (e) {
  //     healthCheck['issues'].add('Health check failed: $e');
  //     healthCheck['status'] = 'critical';
  //   }

  //   return healthCheck;
  // }