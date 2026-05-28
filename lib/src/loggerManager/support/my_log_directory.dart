import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:omni_logger/src/loggerCore/logFiles/log_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Ensure your OmniLogType enum is imported/defined here
// enum OmniLogType { info, warning, error }

class MyLogDirectoryManage {
  // =============================================================================
  // DIRECTORY MANAGEMENT UTILITIES
  // =============================================================================

  static String appName = 'MyApp';
  static String? _resolvedLogPath;

  /// MUST be called and awaited during app startup (e.g., in main.dart)
  /// Example: await MyLogDirectoryManage.init();
  static Future<void> init() async {
    if (kIsWeb) return; // Web has no local file system

    try {
      // getApplicationSupportDirectory provides a hidden, persistent app-specific
      // directory on iOS, Android, Windows, macOS, and Linux natively.
      final supportDir = await getApplicationSupportDirectory();
      _resolvedLogPath = path.join(supportDir.path, 'logs');

      // createSync is used intentionally here; it is fast, avoids async race
      // conditions when the app rapidly fires initial logs, and is standard practice.
      ensureDirectoryExists(_resolvedLogPath);
    } catch (e) {
      debugPrint('OmniLogger: Failed to get ApplicationSupportDirectory: $e');
      // Failsafe Fallback: If native storage fails (e.g., disk full, permission error),
      // safely use temporary directory.
      _resolvedLogPath = path.join(Directory.systemTemp.path, appName, 'logs');
      ensureDirectoryExists(_resolvedLogPath);
    }
  }

  /// Get the platform-appropriate, fully resolved log directory
  static String? getDefaultLogDirectory() {
    if (kIsWeb) return null;

    if (_resolvedLogPath != null) {
      return _resolvedLogPath;
    }

    // Emergency fallback in case init() was forgotten or hasn't finished.
    // systemTemp can be cleared by the OS, but prevents a fatal crash.
    debugPrint(
      '⚠️ OmniLogger Warning: MyLogDirectoryManage.init() was not awaited. '
      'Falling back to volatile system temp directory.',
    );
    final emergencyPath = path.join(Directory.systemTemp.path, appName, 'logs');
    ensureDirectoryExists(emergencyPath);
    return emergencyPath;
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

    // Using .name or .toString() depending on how you structured OmniLogType
    // logType.name is standard for Dart enums in modern Flutter
    final typeStr = logType.name;

    final parts = [logFilePrefix, typeStr, dateStr];

    if (timestamp != null && timestamp.isNotEmpty) {
      parts.add(timestamp);
    }

    return '${parts.join('_')}.$extension';
  }
}
