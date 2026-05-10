import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:omni_logger/omni_logger.dart';

abstract class BaseLoggerMiddleware implements OmniLogger {
  final OmniLogger baseLogger;

  BaseLoggerMiddleware(this.baseLogger);

  @override
  void ensureInitialized() => baseLogger.ensureInitialized();

  @override
  OmniLogConfig get config => baseLogger.config;

  @override
  OmniLogger getLogger({required String className}) =>
      createMiddleware(baseLogger.getLogger(className: className));

  @override
  String? get currentLogFilePath => baseLogger.currentLogFilePath;

  @override
  String? get logDirectory => baseLogger.logDirectory;

  @override
  bool get isFileLoggingReady => baseLogger.isFileLoggingReady;

  @override
  bool get hasInitializationFailed => baseLogger.hasInitializationFailed;

  @override
  String? get lastInitError => baseLogger.lastInitError;

  @override
  Map<String, dynamic> getLogStats() => baseLogger.getLogStats();

  @override
  void printLogStats({required OmniLogger logger}) =>
      baseLogger.printLogStats(logger: logger);

  @override
  bool resetFileLogging() => baseLogger.resetFileLogging();

  @override
  void dispose() => baseLogger.dispose();

  @override
  bool cleanAllLogs() => baseLogger.cleanAllLogs();

  // Handle async logging with fire-and-forget
  @override
  void t(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    unawaited(
      log(
        OmniLogLevel.trace,
        message,
        error: error,
        stackTrace: stackTrace,
      ).catchError(handleAsyncError),
    );
  }

  @override
  void d(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    unawaited(
      log(
        OmniLogLevel.debug,
        message,
        error: error,
        stackTrace: stackTrace,
      ).catchError(handleAsyncError),
    );
  }

  @override
  void i(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    unawaited(
      log(
        OmniLogLevel.info,
        message,
        error: error,
        stackTrace: stackTrace,
      ).catchError(handleAsyncError),
    );
  }

  @override
  void w(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    unawaited(
      log(
        OmniLogLevel.warning,
        message,
        error: error,
        stackTrace: stackTrace,
      ).catchError(handleAsyncError),
    );
  }

  @override
  void e(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    unawaited(
      log(
        OmniLogLevel.error,
        message,
        error: error,
        stackTrace: stackTrace,
      ).catchError(handleAsyncError),
    );
  }

  @override
  void f(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    unawaited(
      log(
        OmniLogLevel.fatal,
        message,
        error: error,
        stackTrace: stackTrace,
      ).catchError(handleAsyncError),
    );
  }

  /// Standardized error handling for async operations - protected for subclasses
  @protected
  void handleAsyncError(dynamic error, StackTrace? stackTrace) {
    if (kDebugMode) {
      debugPrint('$runtimeType: Async logging error: $error\n$stackTrace');
    }
  }

  /// FIXED: Now properly async to match interface
  @override
  Future<void> log(
    OmniLogLevel level,
    dynamic message, {
    dynamic error,
    StackTrace? stackTrace,
  });

  /// Each subclass must return the same type of middleware wrapping the new baseLogger.
  BaseLoggerMiddleware createMiddleware(OmniLogger baseLogger);
}
