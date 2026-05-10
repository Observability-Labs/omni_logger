import 'package:logger/logger.dart';

/// Log levels for omni_logger package
/// Controls logging output - logging can be enabled to include all levels above certain [OmniLogLevel]

enum OmniLogLevel {
  all(0),
  trace(1000),
  debug(2000),
  info(3000),
  warning(4000),
  error(5000),
  fatal(6000),
  off(10000);

  final int value;
  const OmniLogLevel(this.value);

  /// Convert from logger package Level to OmniLogLevel
  static OmniLogLevel fromLoggerLevel(dynamic loggerLevel) {
    if (loggerLevel == null) return OmniLogLevel.info;

    // Handle string conversion
    if (loggerLevel is String) {
      return parseString(loggerLevel) ?? OmniLogLevel.info;
    }

    // Handle logger package Level enum by value comparison
    final value = loggerLevel.toString().split('.').last.toLowerCase();
    return parseString(value) ?? OmniLogLevel.info;
  }

  /// Convert OmniLogLevel to logger package Level
  Level toLoggerLevel() {
    switch (this) {
      case OmniLogLevel.all:
        return Level.all;
      case OmniLogLevel.trace:
        return Level.trace;
      case OmniLogLevel.debug:
        return Level.debug;
      case OmniLogLevel.info:
        return Level.info;
      case OmniLogLevel.warning:
        return Level.warning;
      case OmniLogLevel.error:
        return Level.error;
      case OmniLogLevel.fatal:
        return Level.fatal;
      case OmniLogLevel.off:
        return Level.off;
    }
  }

  /// Parse string to OmniLogLevel
  static OmniLogLevel? parseString(String? levelString) {
    if (levelString == null) return null;

    switch (levelString.toLowerCase()) {
      case 'all':
        return OmniLogLevel.all;
      case 'trace':
        return OmniLogLevel.trace;
      case 'debug':
        return OmniLogLevel.debug;
      case 'info':
        return OmniLogLevel.info;
      case 'warning':
      case 'warn':
        return OmniLogLevel.warning;
      case 'error':
        return OmniLogLevel.error;
      case 'fatal':
        return OmniLogLevel.fatal;
      case 'off':
        return OmniLogLevel.off;
      default:
        return null;
    }
  }

  /// Check if this level is enabled for a given minimum level
  bool isEnabledFor(OmniLogLevel minimumLevel) {
    return value >= minimumLevel.value;
  }

  /// Get all available levels
  static List<OmniLogLevel> get allLevels => OmniLogLevel.values;

  static String getLevelName(OmniLogLevel level) {
    switch (level) {
      case OmniLogLevel.all:
        return 'all';
      case OmniLogLevel.trace:
        return 'trace';
      case OmniLogLevel.debug:
        return 'debug';
      case OmniLogLevel.info:
        return 'info';
      case OmniLogLevel.warning:
        return 'warn';
      case OmniLogLevel.error:
        return 'error';
      case OmniLogLevel.fatal:
        return 'fatal';
      case OmniLogLevel.off:
        return 'off';
    }
  }

  static String getLevelDisplayName(OmniLogLevel level) {
    switch (level) {
      case OmniLogLevel.all:
        return 'ALL';
      case OmniLogLevel.trace:
        return 'TRACE';
      case OmniLogLevel.debug:
        return 'DEBUG';
      case OmniLogLevel.info:
        return 'INFO';
      case OmniLogLevel.warning:
        return 'WARN';
      case OmniLogLevel.error:
        return 'ERROR';
      case OmniLogLevel.fatal:
        return 'FATAL';
      case OmniLogLevel.off:
        return 'OFF';
    }
  }

  static final Map<OmniLogLevel, String> levelTags = {
    OmniLogLevel.all: 'ALL  ',
    OmniLogLevel.trace: 'TRACE',
    OmniLogLevel.debug: 'DEBUG',
    OmniLogLevel.info: 'INFO ',
    OmniLogLevel.warning: 'WARN ',
    OmniLogLevel.error: 'ERROR',
    OmniLogLevel.fatal: 'FATAL',
    OmniLogLevel.off: 'OFF  ',
  };

  static final Map<OmniLogLevel, String> levelIcons = {
    OmniLogLevel.debug: '🐛',
    OmniLogLevel.info: 'ℹ️',
    OmniLogLevel.warning: '⚠️',
    OmniLogLevel.error: '❌',
    OmniLogLevel.fatal: '💀',
    OmniLogLevel.trace: '🔍',
    OmniLogLevel.all: '📝',
    OmniLogLevel.off: '🚫',
  };
}
