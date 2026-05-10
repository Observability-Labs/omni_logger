import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:omni_logger/src/loggerCore/logFiles/log_file.dart';
import 'package:path/path.dart' as path;

class MyLogDirectoryManage {
  // =============================================================================
  // DIRECTORY MANAGEMENT UTILITIES
  // =============================================================================

  static String appName = 'MyApp';

  /// Get platform-appropriate log directory
  static String? getDefaultLogDirectory() {
    try {
      if (kIsWeb) {
        // Web platform: no real file system, so return null
        return null;
      }

      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: use temporary directory
        return path.join(Directory.systemTemp.path, 'logs');
      }

      if (Platform.isWindows) {
        // Windows: use %LOCALAPPDATA%/<app>/logs
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null) {
          return path.join(localAppData, appName, 'logs');
        }
      }

      if (Platform.isMacOS) {
        // macOS: use ~/Library/Logs/<app>
        final home = Platform.environment['HOME'];
        if (home != null) {
          return path.join(home, 'Library', 'Logs', appName);
        }
      }

      if (Platform.isLinux || Platform.isFuchsia) {
        // Linux/Fuchsia: use ~/.local/share/<app>/logs
        final home = Platform.environment['HOME'];
        if (home != null) {
          return path.join(home, '.local', 'share', appName, 'logs');
        }
      }

      // Default fallback
      return path.join(Directory.systemTemp.path, 'logs');
    } catch (e) {
      // coverage:ignore-start
      debugPrint('MyLogDirectoryManage: Error determining log directory: $e');
      // coverage:ignore-end
      return path.join(Directory.systemTemp.path, 'logs');
    }
  }

  /// Ensure directory exists and is writable
  static Directory? ensureDirectoryExists(String? directoryPath) {
    if (directoryPath == null) return null;

    try {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      return directory;
    } catch (e) {
      // coverage:ignore-start
      debugPrint(
        'MyLogDirectoryManage: Error creating directory $directoryPath: $e',
      );
      // coverage:ignore-end
      return null;
    }
  }

  // =============================================================================
  // FILE MANAGEMENT UTILITIES
  // =============================================================================

  /// Generate today's date string for file naming
  static String getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Generate timestamp string for unique file naming
  static String getTimestampString() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Create log file name with proper formatting
  static String createLogFileName({
    required String logFilePrefix,
    required OmniLogType logType,
    String? date,
    String? timestamp,
    String extension = 'log',
  }) {
    final dateStr = date ?? getTodayString();
    final parts = [logFilePrefix, logType, dateStr];

    if (timestamp != null) {
      parts.add(timestamp);
    }

    return '${parts.join('_')}.$extension';
  }
}
