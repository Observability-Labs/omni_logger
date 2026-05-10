import 'package:omni_logger/src/loggerConfig/config_manager.dart';
import 'package:omni_logger/src/loggerLevels/omni_log_levels.dart';

/// Configuration class for controlling logging behavior across environments.
///
/// 🧩 This class defines the **global logging policy**, affecting how logs
/// are written, rotated, retained, and presented.
///
/// 🔧 Key responsibilities:
/// - Configure log **levels** (debug, error, etc.)
/// - Control **file logging**, including size limits and retention policies
/// - Enable/disable **console logging**, **JSON formatting**, **compression**, and more
/// - Support tailored modes for development, production, testing, and other isolates
///
/// 📦 File Logging Notes:
/// - If `enableFileLogging` is true, logs are saved to disk as log files.
/// - Each log file begins with a **static header** written by `writeLogHeader()`,
///   containing metadata like initial size, limits, timestamps, etc.
/// - The header remains static; file size is tracked in-memory to avoid costly updates.
///
/// 🌀 Log Rotation & Retention:
/// - When `maxFileSizeMB` is reached, logging rolls over to a new file with a fresh header.
/// - Rotation resets counters; old files are removed according to:
///   - `maxLogFiles`: maximum number of retained log files
///   - `logRetentionDays`: age-based cleanup
///
/// 📎 Example:
/// A log file's header may show "Current Used: 0MB" at creation,
/// and the file will grow up to `maxFileSizeMB` before rotating.
///
/// 🔐 Compression:
/// - Rotated log files may be compressed if `enableCompression` is true,
///   reducing disk usage.
///
/// 🧪 Use factory constructors for common setups:
/// - `OmniLogConfig.auto()` — automatic mode detection based on Flutter build mode
/// - `OmniLogConfig.autoDatabase()` — config tailored for database isolates
/// - `OmniLogConfig.autoBackground()` — minimal logging for background tasks
/// - `OmniLogConfig.autoNetwork()` — network isolate-specific logging setup
///
/// ✏️ Customize configurations via `.copyWith()` for runtime tweaks.
///
/// 🧠 Internal details:
/// File size after initialization is tracked **in-memory** with `_currentFileSizeInBytes`
/// to avoid rewriting static headers frequently.
///
/// ------------------------------------------------------------------------
///
/// VERY IMPORTANT: AUTO-DETECTS DEBUG, RELEASE, PROFILE MODE: NO CONFIG NEEDED
///
/// The `isProduction` flag is set automatically based on Flutter build mode:
/// - `release` mode = production environment
/// - `debug` and `profile` modes = development or testing environments
///
/// Logging behavior switches automatically with no manual setup required.
///
/// IMPORTANT: NO USERID NEEDED FOR LOGS
/// Note: Logs are designed to capture app-wide events such as exceptions, errors,
/// and important system behaviors. We do not include user ID or any user-specific
/// identifiers in the logs because the primary goal is to track app stability and issues,
/// not to perform user-level auditing or tracking.
///
/// This keeps logs simpler, focused, and avoids privacy concerns related to user
/// data.
class OmniLogConfig {
  // ========================================================================
  // INSTANCE FIELDS - Simplified
  // ========================================================================

  final OmniLogLevel level;
  final OmniLogMode mode;
  final int maxLogFiles;
  final bool enableFileLogging;
  final int maxFileSizeMB;
  final bool enableCompression;
  final String logFilePrefix;
  final bool enableJsonLogging;
  final bool enableConsoleLogging;
  final int logRetentionDays;

  const OmniLogConfig._({
    required this.level,
    required this.mode,
    required this.maxLogFiles,
    required this.enableFileLogging,
    required this.maxFileSizeMB,
    required this.enableCompression,
    required this.logFilePrefix,
    required this.enableJsonLogging,
    required this.enableConsoleLogging,
    required this.logRetentionDays,
  });

  // ========================================================================
  // FACTORY CONSTRUCTORS - Using LogConfigManager
  // ========================================================================

  /// Auto-detect mode and configure accordingly
  factory OmniLogConfig.auto({String? isolatePrefix}) {
    final mode = OmniLogConfigManager.getCurrentMode();
    return OmniLogConfig._fromMode(mode, isolatePrefix);
  }

  /// Production mode - minimal logging
  factory OmniLogConfig.production({String? isolatePrefix}) {
    return OmniLogConfig._fromMode(OmniLogMode.production, isolatePrefix);
  }

  /// Profile mode - moderate logging
  factory OmniLogConfig.profile({String? isolatePrefix}) {
    return OmniLogConfig._fromMode(OmniLogMode.profile, isolatePrefix);
  }

  /// Debug mode - full logging
  factory OmniLogConfig.debug({String? isolatePrefix}) {
    return OmniLogConfig._fromMode(OmniLogMode.debug, isolatePrefix);
  }

  /// Completely disable all logging
  factory OmniLogConfig.off({String? isolatePrefix}) {
    return OmniLogConfig._fromMode(OmniLogMode.off, isolatePrefix);
  }

  /// Remote-only logging - logs are active but nothing saved locally
  factory OmniLogConfig.remoteOnly({String? isolatePrefix}) {
    final mode = OmniLogConfigManager.getCurrentMode();
    final prefix = OmniLogConfigManager.buildPrefix(mode, isolatePrefix);

    return OmniLogConfig._(
      level: OmniLogConfigManager.getLogLevel(mode),
      mode: mode,
      maxLogFiles: 0, // No local files
      enableFileLogging: false, // No local storage
      maxFileSizeMB: 0,
      enableCompression: false,
      logFilePrefix: prefix,
      enableJsonLogging: false,
      enableConsoleLogging: OmniLogConfigManager.isConsoleLoggingEnabled(mode),
      logRetentionDays: 0,
    );
  }

  /// Custom configuration with manual overrides
  factory OmniLogConfig.custom({
    OmniLogMode mode = OmniLogMode.production,
    String? isolatePrefix,
    OmniLogLevel? levelOverride,
    bool? fileLoggingOverride,
    bool? consoleLoggingOverride,
    int? maxFilesOverride,
    int? fileSizeOverride,
    int? retentionOverride,
  }) {
    final prefix = OmniLogConfigManager.buildPrefix(mode, isolatePrefix);

    return OmniLogConfig._(
      level: levelOverride ?? OmniLogConfigManager.getLogLevel(mode),
      mode: mode,
      maxLogFiles: maxFilesOverride ?? OmniLogConfigManager.getMaxFiles(mode),
      enableFileLogging:
          fileLoggingOverride ??
          OmniLogConfigManager.isFileLoggingEnabled(mode),
      maxFileSizeMB:
          fileSizeOverride ?? OmniLogConfigManager.getFileSizeMB(mode),
      enableCompression: OmniLogConfigManager.isCompressionEnabled(mode),
      logFilePrefix: prefix,
      enableJsonLogging: OmniLogConfigManager.isJsonLoggingEnabled(mode),
      enableConsoleLogging:
          consoleLoggingOverride ??
          OmniLogConfigManager.isConsoleLoggingEnabled(mode),
      logRetentionDays:
          retentionOverride ?? OmniLogConfigManager.getRetentionDays(mode),
    );
  }

  /// Specialized configs for different isolates
  factory OmniLogConfig.forDatabase({String isolatePrefix = 'db'}) {
    final mode = OmniLogConfigManager.getCurrentMode();
    return OmniLogConfig.custom(
      mode: mode,
      isolatePrefix: isolatePrefix,
      // Database logs need JSON for analysis
      // Other settings auto-adapt based on mode
    );
  }

  factory OmniLogConfig.forBackground({String isolatePrefix = 'bg'}) {
    final mode = OmniLogConfigManager.getCurrentMode();
    return OmniLogConfig.custom(
      mode: mode,
      isolatePrefix: isolatePrefix,
      fileLoggingOverride: false, // Background tasks shouldn't fill storage
    );
  }

  factory OmniLogConfig.forNetwork({String isolatePrefix = 'network'}) {
    final mode = OmniLogConfigManager.getCurrentMode();
    return OmniLogConfig.custom(
      mode: mode,
      isolatePrefix: isolatePrefix,
      // Network logs often need JSON for analysis
      // Other settings auto-adapt based on mode
    );
  }

  // ========================================================================
  // PRIVATE HELPER
  // ========================================================================

  factory OmniLogConfig._fromMode(OmniLogMode mode, String? isolatePrefix) {
    final prefix = OmniLogConfigManager.buildPrefix(mode, isolatePrefix);

    return OmniLogConfig._(
      level: OmniLogConfigManager.getLogLevel(mode),
      mode: mode,
      maxLogFiles: OmniLogConfigManager.getMaxFiles(mode),
      enableFileLogging: OmniLogConfigManager.isFileLoggingEnabled(mode),
      maxFileSizeMB: OmniLogConfigManager.getFileSizeMB(mode),
      enableCompression: OmniLogConfigManager.isCompressionEnabled(mode),
      logFilePrefix: prefix,
      enableJsonLogging: OmniLogConfigManager.isJsonLoggingEnabled(mode),
      enableConsoleLogging: OmniLogConfigManager.isConsoleLoggingEnabled(mode),
      logRetentionDays: OmniLogConfigManager.getRetentionDays(mode),
    );
  }

  // ========================================================================
  // UTILITY METHODS
  // ========================================================================

  /// Copy method for runtime updates
  OmniLogConfig copyWith({
    OmniLogLevel? level,
    OmniLogMode? mode,
    int? maxLogFiles,
    bool? enableFileLogging,
    int? maxFileSizeMB,
    bool? enableCompression,
    String? logFilePrefix,
    bool? enableJsonLogging,
    bool? enableConsoleLogging,
    int? logRetentionDays,
  }) {
    return OmniLogConfig._(
      level: level ?? this.level,
      mode: mode ?? this.mode,
      maxLogFiles: maxLogFiles ?? this.maxLogFiles,
      enableFileLogging: enableFileLogging ?? this.enableFileLogging,
      maxFileSizeMB: maxFileSizeMB ?? this.maxFileSizeMB,
      enableCompression: enableCompression ?? this.enableCompression,
      logFilePrefix: logFilePrefix ?? this.logFilePrefix,
      enableJsonLogging: enableJsonLogging ?? this.enableJsonLogging,
      enableConsoleLogging: enableConsoleLogging ?? this.enableConsoleLogging,
      logRetentionDays: logRetentionDays ?? this.logRetentionDays,
    );
  }
  // coverage:ignore-start

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'level': level.name,
      'mode': mode.name,
      'maxLogFiles': maxLogFiles,
      'enableFileLogging': enableFileLogging,
      'maxFileSizeMB': maxFileSizeMB,
      'enableCompression': enableCompression,
      'logFilePrefix': logFilePrefix,
      'enableJsonLogging': enableJsonLogging,
      'enableConsoleLogging': enableConsoleLogging,
      'logRetentionDays': logRetentionDays,
    };
  }

  /// Check if logging is completely disabled
  bool get isLoggingDisabled {
    return mode == OmniLogMode.off;
  }

  /// Quick check if this is a high-verbosity config
  bool get isVerbose {
    return level == OmniLogLevel.debug || level == OmniLogLevel.trace;
  }

  /// Get current settings summary
  String get summary {
    return 'Mode: ${mode.name}, Level: ${level.name}, Files: $maxLogFiles×${maxFileSizeMB}MB, Retention: ${logRetentionDays}d';
  }

  @override
  String toString() {
    if (isLoggingDisabled) {
      return 'OmniLogConfig(OFF, prefix: $logFilePrefix)';
    }
    return 'OmniLogConfig($summary, prefix: $logFilePrefix)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OmniLogConfig &&
        other.level == level &&
        other.mode == mode &&
        other.maxLogFiles == maxLogFiles &&
        other.enableFileLogging == enableFileLogging &&
        other.maxFileSizeMB == maxFileSizeMB &&
        other.enableCompression == enableCompression &&
        other.logFilePrefix == logFilePrefix &&
        other.enableJsonLogging == enableJsonLogging &&
        other.enableConsoleLogging == enableConsoleLogging &&
        other.logRetentionDays == logRetentionDays;
  }

  @override
  int get hashCode {
    return Object.hash(
      level,
      mode,
      maxLogFiles,
      enableFileLogging,
      maxFileSizeMB,
      enableCompression,
      logFilePrefix,
      enableJsonLogging,
      enableConsoleLogging,
      logRetentionDays,
    );
  }

  // coverage:ignore-end
}
