import 'package:flutter/foundation.dart';
import 'package:omni_logger/omni_logger.dart';

/// # LogConfigManager: Intelligent Auto-Configuration for Omni Logger
///
/// This class provides **centralized configuration management** with intelligent
/// auto-detection of Flutter build modes and **minimal storage footprint optimization**.
///
/// ## 🎯 Core Design Philosophy
///
/// Uses a **base + increment** approach to ensure production builds use absolute
/// minimal storage while development builds have sufficient logging capacity:
///
/// ```dart
/// // Production (Release): Minimal footprint
/// Base: 1 file × 1MB × 1 day retention = 1MB maximum
///
/// // Profile: Moderate capacity
/// Profile: 2 files × 3MB × 2 days = 6MB maximum
///
/// // Debug: Full capacity
/// Debug: 3 files × 5MB × 3 days = 15MB maximum
/// ```
///
/// ## 🔢 Configuration Values by Build Mode
///
/// | Build Mode | Log Files | Size Per File | Retention | Max Storage |
/// |------------|-----------|---------------|-----------|-------------|
/// | **Production** | 1 | 1MB | 1 day | 1MB |
/// | **Profile** | 2 | 3MB | 2 days | 6MB |
/// | **Debug** | 3 | 5MB | 3 days | 15MB |
///
/// ## 🚀 Auto-Detection Logic
///
/// ```dart
/// // Automatic mode detection:
/// if (kReleaseMode) → LogMode.production   // Minimal logs: 1MB
/// if (kProfileMode) → LogMode.profile      // Moderate logs: 6MB
/// else              → LogMode.debug        // Full logs: 15MB
/// ```
///
/// ## 📊 Usage Examples
///
/// ```dart
/// // Get current auto-detected configuration
/// final mode = LogConfigManager.getCurrentMode();
/// final maxFiles = LogConfigManager.getMaxFiles(mode);        // 3 files
/// final fileSizeMB = LogConfigManager.getFileSizeMB(mode);    // 5MB per file
/// final retention = LogConfigManager.getRetentionDays(mode);  // 3 days retention
///
/// // Inspect all settings for current mode
/// final settings = LogConfigManager.getSettingsForMode(mode);
/// print('Current mode settings: $settings');
///
/// // Build appropriate file prefix
/// final prefix = LogConfigManager.buildPrefix(mode, 'MyApp'); // "debug_MyApp"
/// ```
///
/// ## 🧹 Automatic Cleanup Behavior
///
/// **File Management**:
/// - **File count limit**: Enforces `maxLogFiles` setting
/// - **File size limit**: Rotates at `maxFileSizeMB`
/// - **Retention limit**: Removes files older than `logRetentionDays`
/// - **Cleanup frequency**: Every 100 writes, minimum 1-hour intervals
///
/// ## 🔐 Privacy Integration
///
/// Production mode automatically enables privacy-focused settings:
/// - **Error-level logging only**: Minimal information exposure
/// - **Path sanitization**: User directory info removed from production logs
/// - **Compression enabled**: Further reduces storage footprint
/// - **Console logging disabled**: No debug output in production builds
///
/// ## 📈 Monitoring Your Configuration
///
/// ```dart
/// // Check what configuration is active
/// AppLog.instance.printLogStats(logger: AppLog.instance);
///
/// // Output shows current log files:
/// // ║  📁 FILE INFORMATION
/// // ║    • Total Log Files: 📊 3
/// // ║    • Total Size: 🟢 2.1 MB
/// // ║  📄 File 1 (CURRENT): debug_MyApp_2025-06-13.log
/// // ║  📄 File 2: debug_MyApp_2025-06-12.log
/// // ║  📄 File 3: debug_MyApp_2025-06-11.log
/// ```
///
/// ## 🎛️ Flexible Logging Approach
///
/// Omni Logger uses a **single log stream** approach where you control what gets logged:
///
/// ```dart
/// // All types of logs go to the same stream - you decide the content
/// AppLog.d('General debug information');
/// AppLog.w('Performance warning: slow operation detected');
/// AppLog.e('Error occurred', error: exception, stackTrace: stack);
/// AppLog.f('Critical failure - app crash imminent');
///
/// // Use log levels to filter what you want to see/store
/// // Production: Only errors and fatal logs
/// // Debug: All log levels for comprehensive debugging
/// ```
///
/// ## ✅ Key Benefits
///
/// 1. **Simple Architecture**: One log stream, easy to understand and maintain
/// 2. **User Control**: You decide what to log and at what level
/// 3. **Efficient Storage**: Optimized file management with automatic cleanup
/// 4. **Mode-Aware**: Automatically adjusts limits based on build mode
/// 5. **Privacy-Focused**: Production mode sanitizes sensitive information
class OmniLogConfigManager {
  // ========================================================================
  // BASE CONFIGURATION VALUES - Minimal foundation
  // ========================================================================

  /// Base file count (production uses this, others increment)
  static const int _baseMaxFiles = 1;

  /// Base file size in MB (production uses this, others increment)
  static const int _baseFileSizeMB = 1;

  /// Base retention in days (production uses this, others increment)
  static const int _baseRetentionDays = 1;

  // ========================================================================
  // INCREMENT CONSTANTS - How much to add for each mode
  // ========================================================================

  /// File count increments
  static const int _profileFileIncrement = 1; // Profile: base + 1 = 2 files
  static const int _debugFileIncrement = 2; // Debug: base + 2 = 3 files

  /// File size increments (MB)
  static const int _profileSizeIncrement = 2; // Profile: base + 2 = 3MB
  static const int _debugSizeIncrement = 4; // Debug: base + 4 = 5MB

  /// Retention increments (days)
  static const int _profileRetentionIncrement = 1; // Profile: base + 1 = 2 days
  static const int _debugRetentionIncrement = 2; // Debug: base + 2 = 3 days

  // ========================================================================
  // COMPUTED VALUES - Auto-calculated based on mode
  // ========================================================================

  /// Get max files for current mode
  static int getMaxFiles(OmniLogMode mode) {
    switch (mode) {
      case OmniLogMode.production:
        return _baseMaxFiles;
      case OmniLogMode.profile:
        return _baseMaxFiles + _profileFileIncrement;
      case OmniLogMode.debug:
        return _baseMaxFiles + _debugFileIncrement;
      case OmniLogMode.off:
        return 0;
    }
  }

  /// Get file size for current mode
  static int getFileSizeMB(OmniLogMode mode) {
    switch (mode) {
      case OmniLogMode.production:
        return _baseFileSizeMB;
      case OmniLogMode.profile:
        return _baseFileSizeMB + _profileSizeIncrement;
      case OmniLogMode.debug:
        return _baseFileSizeMB + _debugSizeIncrement;
      case OmniLogMode.off:
        return 0;
    }
  }

  /// Get retention days for current mode
  static int getRetentionDays(OmniLogMode mode) {
    switch (mode) {
      case OmniLogMode.production:
        return _baseRetentionDays;
      case OmniLogMode.profile:
        return _baseRetentionDays + _profileRetentionIncrement;
      case OmniLogMode.debug:
        return _baseRetentionDays + _debugRetentionIncrement;
      case OmniLogMode.off:
        return 0;
    }
  }

  /// Get log level for current mode
  static OmniLogLevel getLogLevel(OmniLogMode mode) {
    switch (mode) {
      case OmniLogMode.production:
        return OmniLogLevel.error;
      case OmniLogMode.profile:
        return OmniLogLevel.warning;
      case OmniLogMode.debug:
        return OmniLogLevel.debug;
      case OmniLogMode.off:
        return OmniLogLevel.off;
    }
  }

  /// Check if file logging should be enabled
  static bool isFileLoggingEnabled(OmniLogMode mode) {
    return mode != OmniLogMode.off;
  }

  /// Check if console logging should be enabled
  static bool isConsoleLoggingEnabled(OmniLogMode mode) {
    return mode == OmniLogMode.debug || mode == OmniLogMode.profile;
  }

  /// Check if compression should be enabled
  static bool isCompressionEnabled(OmniLogMode mode) {
    return mode == OmniLogMode.production;
  }

  /// Check if JSON logging should be enabled
  static bool isJsonLoggingEnabled(OmniLogMode mode) {
    return mode == OmniLogMode.profile;
  }

  // ========================================================================
  // UTILITY METHODS
  // ========================================================================

  /// Auto-detect current mode based on build flags
  static OmniLogMode getCurrentMode() {
    if (kReleaseMode) return OmniLogMode.production;
    if (kProfileMode) return OmniLogMode.profile;
    return OmniLogMode.debug;
  }

  /// Build appropriate prefix for log files
  static String buildPrefix(OmniLogMode mode, [String? isolatePrefix]) {
    final modePrefix = mode.name;
    return isolatePrefix != null ? '${modePrefix}_$isolatePrefix' : modePrefix;
  }

  // coverage:ignore-start
  /// Get all settings for a specific mode (for debugging/inspection)
  static Map<String, dynamic> getSettingsForMode(OmniLogMode mode) {
    return {
      'mode': mode.name,
      'maxFiles': getMaxFiles(mode),
      'fileSizeMB': getFileSizeMB(mode),
      'retentionDays': getRetentionDays(mode),
      'logLevel': getLogLevel(mode).name,
      'fileLogging': isFileLoggingEnabled(mode),
      'consoleLogging': isConsoleLoggingEnabled(mode),
      'compression': isCompressionEnabled(mode),
      'jsonLogging': isJsonLoggingEnabled(mode),
    };
  }

  // coverage:ignore-end
}

/// Simple enum for log modes
enum OmniLogMode { production, profile, debug, off }

/// Extension to add name property to LogMode
extension LogModeExtension on OmniLogMode {
  String get name {
    switch (this) {
      case OmniLogMode.production:
        return 'prod';
      case OmniLogMode.profile:
        return 'profile';
      case OmniLogMode.debug:
        return 'debug';
      case OmniLogMode.off:
        return 'off';
    }
  }
}
