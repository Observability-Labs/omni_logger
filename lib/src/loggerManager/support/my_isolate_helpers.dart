import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:omni_logger/omni_logger.dart';

class MyLogIsolateHelpers {
  static String isolateName = 'main';
  static bool isIsolate = false;

  /// Detect isolate information from provided name or current isolate debugName
  static void detectIsolateInfo(String? providedIsolateName) {
    final currentIsolateName = Isolate.current.debugName;
    isIsolate =
        providedIsolateName != null ||
        (currentIsolateName != null && currentIsolateName != 'main');
    isolateName = providedIsolateName?.trim() ?? currentIsolateName ?? 'main';
  }

  /// Get isolate information map with debug info
  static Map<String, dynamic> getIsolateInfo(
    String? isolateName,
    bool isIsolate,
  ) {
    return {
      'name': isolateName,
      'isIsolate': isIsolate,
      'debugName': Isolate.current.debugName,
      'current': Isolate.current.toString(),
      'hashCode': Isolate.current.hashCode,
    };
  }

  /// Log reset message for debugging
  static void logResetMessage(OmniLogger? instance) {
    if (instance != null && kDebugMode) {
      final testLogger = instance.getLogger(className: 'AppLog');
      testLogger.i('AppLog[$isolateName]: Resetting logging system');
    }
  }

  /// Debug print with isolate name prefix
  static void debugPrintIfNeeded(String message) {
    if (kDebugMode) {
      debugPrint('AppLog[$isolateName]: $message');
    }
  }

  /// Debug print error with stack trace
  static void debugPrintError(String error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('AppLog[$isolateName]: ERROR - $error');
      debugPrint('AppLog[$isolateName]: Stack trace: $stackTrace');
    }
  }

  /// Debug print logger stats
  static void debugPrintStats(OmniLogger myLogger) {
    if (kDebugMode) {
      final stats = myLogger.getLogStats();
      debugPrint('AppLog[$isolateName]: Setup complete - Stats: $stats');
    }
  }

  /// Return current isolate name
  static String getCurrentIsolateName() {
    return isolateName;
  }

  /// Check if current context is isolate
  static bool isCurrentContextIsolate() {
    return isIsolate;
  }

  /// Format isolate info for display/logging
  static String formatIsolateInfo() {
    return 'Isolate: $isolateName (${isIsolate ? 'isolate' : 'main thread'})';
  }
}
