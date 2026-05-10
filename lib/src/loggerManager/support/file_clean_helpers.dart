import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as path;

class MyLogManageFileSizeHelpers {
  // Maximum safe MB value to prevent integer overflow
  static const int _maxLogSizeCapInMB =
      50; // Safety cap, we will only use 10MB max.
  /// Returns all log files in the directory that match the given prefix,
  /// sorted by last modified date (most recent first).
  static List<File> getSortedLogFiles(Directory dir, String prefix) {
    final files = dir
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              path.basename(f.path).startsWith(prefix) &&
              f.path.endsWith('.log'),
        )
        .toList();

    // Sort by most recent first
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// Returns files older than the retention period.
  static List<File> findFilesOlderThan(List<File> files, int retentionDays) {
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: retentionDays));
    final oldFiles = <File>[];

    for (final file in files) {
      try {
        final lastModified = file.lastModifiedSync();
        if (lastModified.isBefore(cutoffDate)) {
          oldFiles.add(file);
        }
      } catch (e) {
        // coverage:ignore-start
        debugPrint(
          'MyLogFileCleanHelpers: Error checking file age for ${file.path}: $e',
        );
        // coverage:ignore-end
      }
    }

    return oldFiles;
  }

  /// Returns the oldest files exceeding the max count (excluding already marked files).
  static List<File> findFilesExceedingMax(
    List<File> allFiles,
    List<File> excludedFiles,
    int maxFiles,
  ) {
    final remainingFiles = allFiles
        .where((f) => !excludedFiles.contains(f))
        .toList();

    if (remainingFiles.length <= maxFiles) {
      return [];
    }

    // Sort by oldest first
    remainingFiles.sort(
      (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
    );
    final excessCount = remainingFiles.length - maxFiles;
    return remainingFiles.take(excessCount).toList();
  }

  /// Deletes the given files from disk. Optionally compresses them before deletion.
  static void deleteFiles(List<File> filesToDelete, bool enableCompression) {
    var deletedCount = 0;

    for (final file in filesToDelete) {
      try {
        if (enableCompression) {
          _compressLogFile(file); // Assuming this is a static utility
        }

        file.deleteSync();
        deletedCount++;
      } catch (e) {
        // coverage:ignore-start
        debugPrint(
          'MyLogFileCleanHelpers: Error deleting old log file ${file.path}: $e',
        );
        // coverage:ignore-end
      }
    }

    if (deletedCount > 0) {
      //debugPrint('MyLogFileCleanHelpers: Cleaned $deletedCount old log files');
    }
  }

  static void _compressLogFile(File logFile) {
    try {
      final compressedPath = '${logFile.path}.gz';
      final compressedFile = File(compressedPath);

      if (!compressedFile.existsSync()) {
        final content = logFile.readAsBytesSync();
        final compressed = gzip.encode(content);
        compressedFile.writeAsBytesSync(compressed);
        // coverage:ignore-start
        debugPrint('MyLogFileCleanHelpers: Compressed ${logFile.path}');
        // coverage:ignore-end
      }
    } catch (e) {
      // coverage:ignore-start
      debugPrint('MyLogFileCleanHelpers: Error compressing log file: $e');
      // coverage:ignore-end
    }
  }

  /// Safely gets file size, handling various file system exceptions
  static int getFileSizeSafely(File? file) {
    if (file == null) return 0;

    try {
      return file.existsSync() ? file.lengthSync() : 0;
    } on FileSystemException catch (e) {
      // coverage:ignore-start
      debugPrint(
        'MyLogManager: FileSystem error getting file size: ${e.message}',
      );
      // coverage:ignore-end
      return 0;
    } catch (e) {
      // coverage:ignore-start
      debugPrint('MyLogManager: Unexpected error getting file size: $e');
      // coverage:ignore-end
      return 0;
    }
  }

  /// Safely calculates max file size in bytes
  static int calculateMaxFileSize(int maxFileSizeMB) {
    return maxFileSizeMB * 1024 * 1024;
  }

  /// Validates and caps maxFileSizeMB to prevent overflow
  static int validateMaxFileSize(int maxFileSizeMB) {
    if (maxFileSizeMB <= 0) {
      // coverage:ignore-start
      debugPrint(
        'MyLogManager: Invalid maxFileSizeMB ($maxFileSizeMB), using default 10MB',
      );
      // coverage:ignore-end
      return 10;
    }

    if (maxFileSizeMB > _maxLogSizeCapInMB) {
      // coverage:ignore-start
      debugPrint(
        'MyLogManager: maxFileSizeMB ($maxFileSizeMB) too large, capping at $_maxLogSizeCapInMB MB',
      );
      // coverage:ignore-end
      return _maxLogSizeCapInMB;
    }

    return maxFileSizeMB;
  }

  /// Creates a new log file safely, handling race conditions
  static File? createLogFileSafely(String filePath) {
    try {
      final file = File(filePath);
      file.createSync(recursive: true);
      return file;
    } on FileSystemException catch (e) {
      // Error code 17 typically means "File exists" on Unix systems
      // Error code 183 typically means "File exists" on Windows
      if (e.osError?.errorCode == 17 || e.osError?.errorCode == 183) {
        // File already exists, which is acceptable
        return File(filePath);
      }
      // coverage:ignore-start
      debugPrint(
        'MyLogManager: FileSystem error creating log file: ${e.message}',
      );
      // coverage:ignore-end
      return null;
    } catch (e) {
      // coverage:ignore-start
      debugPrint('MyLogManager: Unexpected error creating log file: $e');
      // coverage:ignore-end
      return null;
    }
  }

  /// Safely writes content to log file with proper error handling
  static bool writeLogSafely(File logFile, String content, FileMode mode) {
    try {
      logFile.writeAsStringSync(content, mode: mode, flush: true);
      return true;
    } on FileSystemException catch (e) {
      // coverage:ignore-start
      debugPrint('MyLogManager: FileSystem error writing to log: ${e.message}');
      // coverage:ignore-end
      return false;
    } catch (e) {
      // coverage:ignore-start
      debugPrint('MyLogManager: Unexpected error writing to log: $e');
      // coverage:ignore-end
      return false;
    }
  }

  /// Formats large byte values with thousands separators
  static String formatBytes(int bytes) {
    if (bytes < 0) return '0';
    return bytes.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
