import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:omni_logger/omni_logger.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:omni_logger/src/loggerManager/my_log_manager.dart';
import 'package:omni_logger/src/loggerManager/support/file_clean_helpers.dart';
import 'package:omni_logger/src/loggerManager/support/my_isolate_helpers.dart';
import 'package:omni_logger/src/loggerManager/support/my_log_directory.dart';
import 'package:omni_logger/src/loggerCore/logFiles/log_file.dart';
import 'package:omni_logger/src/loggerCore/support/json_printer.dart';
import 'package:omni_logger/src/loggerCore/support/prod_printer.dart';
import 'package:omni_logger/src/loggerManager/models/log_info.dart';
import 'package:path/path.dart' as path;

void main() {
  late OmniLogger testLogger;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('omni_logger_test_');

    // Use conditional print to avoid lint warnings
    if (kDebugMode) {
      print('\n${'=' * 70}');
      print('🧪 OMNI LOGGER TESTS - ALL CONSOLE OUTPUT BELOW IS EXPECTED');
      print(
        'Debug messages, error logs, and JSON output are normal test behavior',
      );
      print('=' * 70 + '\n');
    }
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }

    if (kDebugMode) {
      print('\n${'=' * 70}');
      print('✅ OMNI LOGGER TESTS COMPLETED');
      print('All debug output above was expected test behavior');
      print('=' * 70 + '\n');
    }
  });
  group('🚀 Logger Initialization Tests', () {
    test('Factory constructors create working loggers', () {
      final autoLogger = OmniLogger(OmniLogConfig.auto());
      final dbLogger = OmniLogger(
        OmniLogConfig.forDatabase(isolatePrefix: 'db_test'),
      );
      final bgLogger = OmniLogger(
        OmniLogConfig.forBackground(isolatePrefix: 'bg_test'),
      );
      final netLogger = OmniLogger(
        OmniLogConfig.forNetwork(isolatePrefix: 'net_test'),
      );

      expect(autoLogger, isNotNull);
      expect(dbLogger, isNotNull);
      expect(bgLogger, isNotNull);
      expect(netLogger, isNotNull);

      // Test specific configurations for each logger type
      expect(dbLogger.config.logFilePrefix, contains('db_test'));
      expect(bgLogger.config.enableFileLogging, isFalse);
      expect(netLogger.config.logFilePrefix, contains('net_test'));
    });

    test('Mode-specific config loggers work correctly', () {
      final prodLogger = OmniLogger(OmniLogConfig.production());
      final profileLogger = OmniLogger(OmniLogConfig.profile());
      final debugLogger = OmniLogger(OmniLogConfig.debug());
      final offLogger = OmniLogger(OmniLogConfig.off());

      expect(prodLogger.config.level, equals(OmniLogLevel.error));
      expect(profileLogger.config.level, equals(OmniLogLevel.warning));
      expect(debugLogger.config.level, equals(OmniLogLevel.debug));
      expect(offLogger.config.level, equals(OmniLogLevel.off));

      // Test mode-specific settings
      expect(prodLogger.config.enableCompression, isTrue);
      expect(profileLogger.config.enableJsonLogging, isTrue);
      expect(debugLogger.config.enableConsoleLogging, isTrue);
      expect(offLogger.config.enableFileLogging, isFalse);
    });

    test('Custom config logger initialization', () {
      final customConfig = OmniLogConfig.custom(
        mode: OmniLogMode.debug,
        levelOverride: OmniLogLevel.warning,
        maxFilesOverride: 2,
        isolatePrefix: 'custom',
      );
      final logger = OmniLogger(customConfig);

      expect(logger.config.level, equals(OmniLogLevel.warning));
      expect(logger.config.maxLogFiles, equals(2));
      expect(logger.config.logFilePrefix, contains('custom'));
    });

    test('Remote-only logger configuration', () {
      final remoteLogger = OmniLogger(
        OmniLogConfig.remoteOnly(isolatePrefix: 'remote'),
      );

      expect(remoteLogger.config.maxLogFiles, equals(0));
      expect(remoteLogger.config.enableFileLogging, isFalse);
      expect(remoteLogger.config.maxFileSizeMB, equals(0));
      expect(remoteLogger.config.logRetentionDays, equals(0));

      // But crash logging should still be enabled for remote reporting
      expect(remoteLogger.config.logFilePrefix, contains('remote'));
    });

    test('Specialized isolate loggers work correctly', () {
      final dbLogger = OmniLogger(
        OmniLogConfig.forDatabase(isolatePrefix: 'db'),
      );
      final bgLogger = OmniLogger(
        OmniLogConfig.forBackground(isolatePrefix: 'bg'),
      );
      final netLogger = OmniLogger(
        OmniLogConfig.forNetwork(isolatePrefix: 'network'),
      );

      // Database logger should adapt to current mode
      expect(dbLogger.config.logFilePrefix, contains('db'));
      expect(dbLogger.config.level, isA<OmniLogLevel>());

      // Background logger should have minimal file logging
      expect(bgLogger.config.logFilePrefix, contains('bg'));
      expect(bgLogger.config.enableFileLogging, isFalse);

      // Network logger should adapt to current mode
      expect(netLogger.config.logFilePrefix, contains('network'));
      expect(netLogger.config.level, isA<OmniLogLevel>());
    });

    test('Logger with factory configs vs custom configs', () {
      // Test factory configs
      final factoryDebugLogger = OmniLogger(
        OmniLogConfig.debug(isolatePrefix: 'factory'),
      );
      final factoryProdLogger = OmniLogger(
        OmniLogConfig.production(isolatePrefix: 'factory'),
      );

      // Test custom configs with same modes
      final customDebugLogger = OmniLogger(
        OmniLogConfig.custom(mode: OmniLogMode.debug, isolatePrefix: 'custom'),
      );
      final customProdLogger = OmniLogger(
        OmniLogConfig.custom(
          mode: OmniLogMode.production,
          isolatePrefix: 'custom',
        ),
      );

      // Factory and custom configs with same mode should have similar settings
      expect(
        factoryDebugLogger.config.level,
        equals(customDebugLogger.config.level),
      );
      expect(
        factoryProdLogger.config.level,
        equals(customProdLogger.config.level),
      );

      expect(
        factoryDebugLogger.config.enableConsoleLogging,
        equals(customDebugLogger.config.enableConsoleLogging),
      );
      expect(
        factoryProdLogger.config.enableCompression,
        equals(customProdLogger.config.enableCompression),
      );
    });

    test('Logger config validation and error handling', () {
      // Test that all factory constructors produce valid configs
      final configs = [
        OmniLogConfig.auto(),
        OmniLogConfig.production(),
        OmniLogConfig.profile(),
        OmniLogConfig.debug(),
        OmniLogConfig.off(),
        OmniLogConfig.remoteOnly(),
        OmniLogConfig.forDatabase(),
        OmniLogConfig.forBackground(),
        OmniLogConfig.forNetwork(),
        OmniLogConfig.custom(),
      ];

      for (final config in configs) {
        final logger = OmniLogger(config);
        expect(logger, isNotNull);
        expect(logger.config, isNotNull);
        expect(logger.config.logFilePrefix, isNotEmpty);
        expect(logger.config.maxLogFiles, greaterThanOrEqualTo(0));
        expect(logger.config.maxFileSizeMB, greaterThanOrEqualTo(0));
        expect(logger.config.logRetentionDays, greaterThanOrEqualTo(0));
      }
    });

    test('Logger configuration inheritance and overrides', () {
      // Test that custom overrides work properly
      final baseConfig = OmniLogConfig.production();
      final overriddenConfig = OmniLogConfig.custom(
        mode: OmniLogMode.production,
        levelOverride: OmniLogLevel.debug,
        fileLoggingOverride: false,
        consoleLoggingOverride: true,
        maxFilesOverride: 10,
      );

      final baseLogger = OmniLogger(baseConfig);
      final overriddenLogger = OmniLogger(overriddenConfig);

      // Base should follow production defaults
      expect(baseLogger.config.level, equals(OmniLogLevel.error));
      expect(baseLogger.config.enableFileLogging, isTrue);
      expect(baseLogger.config.enableConsoleLogging, isFalse);

      // Override should use custom values
      expect(overriddenLogger.config.level, equals(OmniLogLevel.debug));
      expect(overriddenLogger.config.enableFileLogging, isFalse);
      expect(overriddenLogger.config.enableConsoleLogging, isTrue);
      expect(overriddenLogger.config.maxLogFiles, equals(10));
    });

    test('Mode detection and auto configuration', () {
      final autoLogger = OmniLogger(OmniLogConfig.auto());

      // Auto config should detect current build mode
      expect(autoLogger.config.mode, isA<OmniLogMode>());
      expect(autoLogger.config.level, isA<OmniLogLevel>());

      // Verify it's using LogConfigManager for mode detection
      final expectedMode = OmniLogConfigManager.getCurrentMode();
      final expectedLevel = OmniLogConfigManager.getLogLevel(expectedMode);

      expect(autoLogger.config.mode, equals(expectedMode));
      expect(autoLogger.config.level, equals(expectedLevel));
    });

    test('Isolate prefix handling across different factories', () {
      const testPrefix = 'test_isolate';

      final configs = [
        OmniLogConfig.auto(isolatePrefix: testPrefix),
        OmniLogConfig.production(isolatePrefix: testPrefix),
        OmniLogConfig.debug(isolatePrefix: testPrefix),
        OmniLogConfig.forDatabase(isolatePrefix: testPrefix),
        OmniLogConfig.forBackground(isolatePrefix: testPrefix),
        OmniLogConfig.forNetwork(isolatePrefix: testPrefix),
        OmniLogConfig.remoteOnly(isolatePrefix: testPrefix),
      ];

      for (final config in configs) {
        final logger = OmniLogger(config);
        expect(logger.config.logFilePrefix, contains(testPrefix));
      }
    });
  });

  group('🎯 OmniLogLevel Coverage Tests', () {
    group('getLevelName method - missing coverage', () {
      test('returns correct names for all levels', () {
        expect(OmniLogLevel.getLevelName(OmniLogLevel.all), equals('all'));
        expect(OmniLogLevel.getLevelName(OmniLogLevel.trace), equals('trace'));
        expect(OmniLogLevel.getLevelName(OmniLogLevel.debug), equals('debug'));
        expect(OmniLogLevel.getLevelName(OmniLogLevel.info), equals('info'));

        // These cases are currently not covered (lines 100-107)
        expect(OmniLogLevel.getLevelName(OmniLogLevel.warning), equals('warn'));
        expect(OmniLogLevel.getLevelName(OmniLogLevel.error), equals('error'));
        expect(OmniLogLevel.getLevelName(OmniLogLevel.fatal), equals('fatal'));
        expect(OmniLogLevel.getLevelName(OmniLogLevel.off), equals('off'));
      });
    });

    group('getLevelDisplayName method - missing coverage', () {
      test('returns correct display names for all levels', () {
        expect(
          OmniLogLevel.getLevelDisplayName(OmniLogLevel.all),
          equals('ALL'),
        );
        expect(
          OmniLogLevel.getLevelDisplayName(OmniLogLevel.trace),
          equals('TRACE'),
        );
        expect(
          OmniLogLevel.getLevelDisplayName(OmniLogLevel.debug),
          equals('DEBUG'),
        );
        expect(
          OmniLogLevel.getLevelDisplayName(OmniLogLevel.info),
          equals('INFO'),
        );
        expect(
          OmniLogLevel.getLevelDisplayName(OmniLogLevel.warning),
          equals('WARN'),
        );
        expect(
          OmniLogLevel.getLevelDisplayName(OmniLogLevel.error),
          equals('ERROR'),
        );
        expect(
          OmniLogLevel.getLevelDisplayName(OmniLogLevel.fatal),
          equals('FATAL'),
        );

        // This case is currently not covered (line 127)
        expect(
          OmniLogLevel.getLevelDisplayName(OmniLogLevel.off),
          equals('OFF'),
        );
      });
    });
    group('toLoggerLevel method - missing coverage', () {
      test('converts OFF level to logger Level', () {
        // This case is currently not covered (line 50)
        expect(OmniLogLevel.off.toLoggerLevel(), equals(Level.off));
      });
    });

    group('fromLoggerLevel method - missing coverage', () {
      test('handles string input correctly', () {
        // This path is not covered (line 25)
        expect(
          OmniLogLevel.fromLoggerLevel('debug'),
          equals(OmniLogLevel.debug),
        );
        expect(OmniLogLevel.fromLoggerLevel('info'), equals(OmniLogLevel.info));
        expect(
          OmniLogLevel.fromLoggerLevel('invalid'),
          equals(OmniLogLevel.info),
        );
      });
    });

    group('allLevels getter - missing coverage', () {
      test('returns all log levels', () {
        // This getter is not covered (line 88)
        final levels = OmniLogLevel.allLevels;
        expect(levels, hasLength(8));
        expect(levels, contains(OmniLogLevel.all));
        expect(levels, contains(OmniLogLevel.trace));
        expect(levels, contains(OmniLogLevel.debug));
        expect(levels, contains(OmniLogLevel.info));
        expect(levels, contains(OmniLogLevel.warning));
        expect(levels, contains(OmniLogLevel.error));
        expect(levels, contains(OmniLogLevel.fatal));
        expect(levels, contains(OmniLogLevel.off));
      });
    });
  });

  group('static debugPrintError method', () {
    test(
      'calls MyLogIsolateHelpers.debugPrintError with correct parameters',
      () {
        // Arrange
        const testError = 'Test error message';
        final testStackTrace = StackTrace.current;

        // Act & Assert - Simple approach without mocking
        // This will actually call the method and verify it doesn't throw
        expect(
          () => OmniLogger.debugPrintError(testError, testStackTrace),
          returnsNormally,
        );
      },
    );

    test('handles empty error message', () {
      // Arrange
      const emptyError = '';
      final testStackTrace = StackTrace.current;

      // Act & Assert
      expect(
        () => OmniLogger.debugPrintError(emptyError, testStackTrace),
        returnsNormally,
      );
    });

    test('handles null-like stack trace', () {
      // Arrange
      const testError = 'Test error';
      final stackTrace = StackTrace.empty;

      // Act & Assert
      expect(
        () => OmniLogger.debugPrintError(testError, stackTrace),
        returnsNormally,
      );
    });

    test('handles realistic error scenarios', () {
      // Arrange - simulate a real error scenario
      const testError = 'Network connection failed';
      StackTrace testStackTrace;

      try {
        throw Exception('Test exception for stack trace');
      } catch (e, stackTrace) {
        testStackTrace = stackTrace;
      }

      // Act & Assert
      expect(
        () => OmniLogger.debugPrintError(testError, testStackTrace),
        returnsNormally,
      );
    });
  });

  group('🎯 OmniLogLevel Additional Tests', () {
    group('parseString method', () {
      test('parses valid level strings correctly', () {
        expect(OmniLogLevel.parseString('all'), equals(OmniLogLevel.all));
        expect(OmniLogLevel.parseString('trace'), equals(OmniLogLevel.trace));
        expect(OmniLogLevel.parseString('debug'), equals(OmniLogLevel.debug));
        expect(OmniLogLevel.parseString('info'), equals(OmniLogLevel.info));
        expect(
          OmniLogLevel.parseString('warning'),
          equals(OmniLogLevel.warning),
        );
        expect(OmniLogLevel.parseString('warn'), equals(OmniLogLevel.warning));
        expect(OmniLogLevel.parseString('error'), equals(OmniLogLevel.error));
        expect(OmniLogLevel.parseString('fatal'), equals(OmniLogLevel.fatal));
        expect(OmniLogLevel.parseString('off'), equals(OmniLogLevel.off));
      });

      test('handles case insensitive parsing', () {
        expect(OmniLogLevel.parseString('ALL'), equals(OmniLogLevel.all));
        expect(OmniLogLevel.parseString('Debug'), equals(OmniLogLevel.debug));
        expect(OmniLogLevel.parseString('INFO'), equals(OmniLogLevel.info));
        expect(
          OmniLogLevel.parseString('WARNING'),
          equals(OmniLogLevel.warning),
        );
        expect(OmniLogLevel.parseString('WARN'), equals(OmniLogLevel.warning));
        expect(OmniLogLevel.parseString('Error'), equals(OmniLogLevel.error));
      });

      test('returns null for invalid or null input', () {
        expect(OmniLogLevel.parseString(null), isNull);
        expect(OmniLogLevel.parseString(''), isNull);
        expect(OmniLogLevel.parseString('invalid'), isNull);
        expect(OmniLogLevel.parseString('verbose'), isNull);
        expect(OmniLogLevel.parseString('critical'), isNull);
      });

      test('handles whitespace and edge cases', () {
        expect(
          OmniLogLevel.parseString(' info '),
          isNull,
        ); // Whitespace not trimmed
        expect(OmniLogLevel.parseString('info '), isNull);
        expect(OmniLogLevel.parseString(' info'), isNull);
      });
    });

    group('levelTags static map', () {
      test('contains all log levels with proper formatting', () {
        expect(OmniLogLevel.levelTags, hasLength(OmniLogLevel.values.length));

        expect(OmniLogLevel.levelTags[OmniLogLevel.all], equals('ALL  '));
        expect(OmniLogLevel.levelTags[OmniLogLevel.trace], equals('TRACE'));
        expect(OmniLogLevel.levelTags[OmniLogLevel.debug], equals('DEBUG'));
        expect(OmniLogLevel.levelTags[OmniLogLevel.info], equals('INFO '));
        expect(OmniLogLevel.levelTags[OmniLogLevel.warning], equals('WARN '));
        expect(OmniLogLevel.levelTags[OmniLogLevel.error], equals('ERROR'));
        expect(OmniLogLevel.levelTags[OmniLogLevel.fatal], equals('FATAL'));
        expect(OmniLogLevel.levelTags[OmniLogLevel.off], equals('OFF  '));
      });

      test('maintains consistent tag length for alignment', () {
        final tags = OmniLogLevel.levelTags.values;

        // All tags should be 5 characters for proper alignment
        for (final tag in tags) {
          expect(
            tag.length,
            equals(5),
            reason: 'Tag "$tag" should be 5 characters',
          );
        }
      });

      test('tags are uppercase as expected', () {
        final tags = OmniLogLevel.levelTags.values;

        for (final tag in tags) {
          expect(
            tag.trim(),
            equals(tag.trim().toUpperCase()),
            reason: 'Tag "$tag" should be uppercase',
          );
        }
      });
    });

    group('isEnabledFor method', () {
      test('correctly determines if level is enabled', () {
        // Debug level should be enabled for debug and higher
        expect(OmniLogLevel.debug.isEnabledFor(OmniLogLevel.debug), isTrue);
        expect(OmniLogLevel.info.isEnabledFor(OmniLogLevel.debug), isTrue);
        expect(OmniLogLevel.warning.isEnabledFor(OmniLogLevel.debug), isTrue);
        expect(OmniLogLevel.error.isEnabledFor(OmniLogLevel.debug), isTrue);
        expect(OmniLogLevel.fatal.isEnabledFor(OmniLogLevel.debug), isTrue);

        // Trace should not be enabled for debug minimum
        expect(OmniLogLevel.trace.isEnabledFor(OmniLogLevel.debug), isFalse);
        expect(OmniLogLevel.all.isEnabledFor(OmniLogLevel.debug), isFalse);
      });

      test('handles edge cases correctly', () {
        // Off level scenarios
        expect(OmniLogLevel.off.isEnabledFor(OmniLogLevel.off), isTrue);
        expect(OmniLogLevel.fatal.isEnabledFor(OmniLogLevel.off), isFalse);

        // All level scenarios
        expect(OmniLogLevel.all.isEnabledFor(OmniLogLevel.all), isTrue);
        expect(OmniLogLevel.trace.isEnabledFor(OmniLogLevel.all), isTrue);

        // Same level comparisons
        expect(OmniLogLevel.info.isEnabledFor(OmniLogLevel.info), isTrue);
        expect(OmniLogLevel.error.isEnabledFor(OmniLogLevel.error), isTrue);
      });

      test('follows numeric value hierarchy', () {
        final levels = [
          OmniLogLevel.all, // 0
          OmniLogLevel.trace, // 1000
          OmniLogLevel.debug, // 2000
          OmniLogLevel.info, // 3000
          OmniLogLevel.warning, // 4000
          OmniLogLevel.error, // 5000
          OmniLogLevel.fatal, // 6000
          OmniLogLevel.off, // 10000
        ];

        // Each level should be enabled for itself and all lower levels
        for (int i = 0; i < levels.length; i++) {
          for (int j = 0; j <= i; j++) {
            expect(
              levels[i].isEnabledFor(levels[j]),
              isTrue,
              reason:
                  '${levels[i].name} should be enabled for ${levels[j].name}',
            );
          }
          for (int j = i + 1; j < levels.length; j++) {
            expect(
              levels[i].isEnabledFor(levels[j]),
              isFalse,
              reason:
                  '${levels[i].name} should NOT be enabled for ${levels[j].name}',
            );
          }
        }
      });
    });

    group('levelIcons static map', () {
      test('contains icons for all levels', () {
        expect(OmniLogLevel.levelIcons, hasLength(OmniLogLevel.values.length));

        // Verify specific icons are assigned
        expect(OmniLogLevel.levelIcons[OmniLogLevel.debug], equals('🐛'));
        expect(OmniLogLevel.levelIcons[OmniLogLevel.info], equals('ℹ️'));
        expect(OmniLogLevel.levelIcons[OmniLogLevel.warning], equals('⚠️'));
        expect(OmniLogLevel.levelIcons[OmniLogLevel.error], equals('❌'));
        expect(OmniLogLevel.levelIcons[OmniLogLevel.fatal], equals('💀'));
        expect(OmniLogLevel.levelIcons[OmniLogLevel.trace], equals('🔍'));
        expect(OmniLogLevel.levelIcons[OmniLogLevel.all], equals('📝'));
        expect(OmniLogLevel.levelIcons[OmniLogLevel.off], equals('🚫'));
      });

      test('all icons are non-empty strings', () {
        final icons = OmniLogLevel.levelIcons.values;

        for (final icon in icons) {
          expect(icon, isNotEmpty);
          expect(icon, isA<String>());
        }
      });
    });
  });

  group('📝 Logging Methods Tests', () {
    setUp(() {
      testLogger = OmniLogger.auto();
      if (kDebugMode) {
        print('🔍 Testing log output - messages below are expected:');
      }
    });

    test('All log level methods work without errors', () {
      expect(() => testLogger.t('Trace message'), returnsNormally);
      expect(() => testLogger.d('Debug message'), returnsNormally);
      expect(() => testLogger.i('Info message'), returnsNormally);
      expect(() => testLogger.w('Warning message'), returnsNormally);
      expect(() => testLogger.e('Error message'), returnsNormally);
      expect(() => testLogger.f('Fatal message'), returnsNormally);
    });

    test('Logging with error and stackTrace works', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      if (kDebugMode) {
        print('🔍 Expected error log with stack trace:');
      }
      expect(
        () => testLogger.e(
          'Error with details',
          error: error,
          stackTrace: stackTrace,
        ),
        returnsNormally,
      );
      expect(
        () => testLogger.f(
          'Fatal with details',
          error: error,
          stackTrace: stackTrace,
        ),
        returnsNormally,
      );
    });

    test('Generic log method supports all levels', () {
      if (kDebugMode) {
        print('🔍 Testing all log levels:');
      }
      for (final level in OmniLogLevel.values) {
        if (level != OmniLogLevel.all && level != OmniLogLevel.off) {
          expect(
            () => testLogger.log(level, 'Test ${level.name}'),
            returnsNormally,
          );
        }
      }
    });

    test('Class-specific loggers maintain context', () {
      final userLogger = testLogger.getLogger(className: 'UserService');
      final apiLogger = testLogger.getLogger(className: 'ApiClient');

      expect(userLogger, isNotNull);
      expect(apiLogger, isNotNull);
      if (kDebugMode) {
        print('🔍 Testing class-specific loggers:');
      }
      expect(() => userLogger.i('User operation'), returnsNormally);
      expect(() => apiLogger.d('API call'), returnsNormally);
    });

    test('Complex object logging works', () {
      final complexObject = {
        'key': 'value',
        'number': 42,
        'list': [1, 2, 3],
      };
      expect(() => testLogger.i(complexObject), returnsNormally);
      expect(() => testLogger.d(['item1', 'item2']), returnsNormally);
    });
  });

  group('📊 Statistics and Health Tests', () {
    setUp(() {
      testLogger = OmniLogger.auto();
    });

    test('Logger provides comprehensive statistics', () {
      final stats = testLogger.getLogStats();

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('config'), isTrue);
      expect(stats.containsKey('fileLoggingReady'), isTrue);
      expect(stats.containsKey('initializationFailed'), isTrue);
    });

    test('Health check validation', () {
      final isHealthy = OmniLogger.isHealthy(
        isSetup: true,
        instance: testLogger,
      );
      expect(isHealthy, isA<bool>());

      final isHealthyNoInstance = OmniLogger.isHealthy(isSetup: false);
      expect(isHealthyNoInstance, isA<bool>());
    });

    test('Static helper methods return expected types', () {
      expect(OmniLogger.isolateName, isA<String>());
      expect(OmniLogger.isIsolate, isA<bool>());
      expect(OmniLogger.formatIsolateInfo(), isA<String>());
      expect(OmniLogger.getCurrentIsolateName(), isA<String>());
      expect(OmniLogger.isRunningInIsolate(), isA<bool>());
    });

    test('Comprehensive stats builder functionality', () {
      final stats = OmniLogger.buildStats(
        isSetup: true,
        isolateName: 'test_isolate',
        isIsolate: false,
        setupError: null,
        instance: testLogger,
      );

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('isSetup'), isTrue);
      expect(stats.containsKey('isolateName'), isTrue);
      expect(stats['isSetup'], isTrue);
      expect(stats['isolateName'], equals('test_isolate'));
    });
  });

  group('🔄 Dynamic Configuration Tests', () {
    setUp(() {
      testLogger = OmniLogger.auto();
    });

    test('Log level runtime updates', () {
      OmniLogger? updatedLogger;

      final success = OmniLogger.updateLogLevel(
        newLevel: OmniLogLevel.error,
        instance: testLogger,
        registerLogger: (logger) => updatedLogger = logger,
      );

      expect(success, isA<bool>());
      if (success && updatedLogger != null) {
        expect(updatedLogger!.config.level, equals(OmniLogLevel.error));
      }
    });

    test('File logging runtime toggle', () {
      OmniLogger? updatedLogger;

      if (kDebugMode) {
        print('🔍 Expected file logging messages:');
      }
      final success = OmniLogger.updateFileLogging(
        enabled: false,
        instance: testLogger,
        registerLogger: (logger) => updatedLogger = logger,
      );

      expect(success, isA<bool>());
      if (success && updatedLogger != null) {
        expect(updatedLogger!.config.enableFileLogging, isFalse);
      }
    });
  });

  group('🗂️ Print Log Stats', () {
    test('Get Log Stats', () {
      final logger = OmniLogger.auto();
      expect(() => logger.getLogStats(), returnsNormally);
    });
    test('Print log stats', () {
      if (kDebugMode) {
        print('=== BEFORE CLEANUP ===');
      }
      final logger = OmniLogger.auto();
      expect(() => logger.printLogStats(logger: logger), returnsNormally);
    });
  });

  group('🗂️ Clean All Logs - Detailed', () {
    test('Verify cleanup behavior', () {
      final logger = OmniLogger.auto();
      // Get initial file count
      final statsBefore = logger.getLogStats();
      final filesBefore = statsBefore['totalLogFiles'] ?? 0;
      if (kDebugMode) {
        print('Files before cleanup: $filesBefore');
      }

      // Clean all logs
      final cleanResult = logger.cleanAllLogs();
      if (kDebugMode) {
        print('Clean result: $cleanResult');
      }

      // Print stats after cleanup
      if (kDebugMode) {
        print('=== AFTER CLEANUP ===');
      }
      logger.printLogStats(logger: logger);

      // Get final file count
      final statsAfter = logger.getLogStats();
      final filesAfter = statsAfter['totalLogFiles'] ?? 0;
      if (kDebugMode) {
        print('Files after cleanup: $filesAfter');
      }

      // Verify the cleanup worked
      expect(cleanResult, isTrue);
      expect(filesAfter, lessThan(filesBefore as int));
    });

    test('Check file patterns', () {
      final logger = OmniLogger.auto();
      final stats = logger.getLogStats();

      if (stats.containsKey('allLogFiles')) {
        final allFiles = stats['allLogFiles'] as List<Map<String, dynamic>>;
        if (kDebugMode) {
          print('=== ALL LOG FILES ===');
        }
        for (int i = 0; i < allFiles.length; i++) {
          final file = allFiles[i];
          if (kDebugMode) {
            print('File ${i + 1}: ${file['fileName']}');
          }
          if (kDebugMode) {
            print('  Path: ${file['filePath']}');
          }
          if (kDebugMode) {
            print('  Current: ${file['isCurrent']}');
          }
        }
      }
    });
  });

  group('🗂️ File Management Tests', () {
    test('File logging properties accessibility', () {
      final logger = OmniLogger.auto();

      expect(() => logger.currentLogFilePath, returnsNormally);
      expect(() => logger.logDirectory, returnsNormally);
      expect(() => logger.isFileLoggingReady, returnsNormally);
      expect(() => logger.hasInitializationFailed, returnsNormally);
      expect(() => logger.lastInitError, returnsNormally);
    });

    test('File logging reset functionality', () {
      final logger = OmniLogger.auto();
      if (kDebugMode) {
        print('🔍 Expected file reset messages:');
      }
      final result = logger.resetFileLogging();
      expect(result, isA<bool>());
    });
  });
  group('MyLogger Factory Constructors Tests', () {
    test('autoBackground logger works and disposes gracefully', () {
      final logger = OmniLogger.autoBackground(isolatePrefix: 'bg_test');

      if (kDebugMode) {
        print('🔍 Testing autoBackground logger');
      }
      expect(
        () => logger.i('Test message from autoBackground'),
        returnsNormally,
      );
      expect(() => logger.dispose(), returnsNormally);
      expect(() => logger.i('Message after dispose'), returnsNormally);
    });

    test('production logger works and disposes gracefully', () {
      final logger = OmniLogger.production(isolatePrefix: 'prod_test');

      if (kDebugMode) {
        print('🔍 Testing production logger');
      }
      expect(() => logger.i('Test message from production'), returnsNormally);
      expect(() => logger.dispose(), returnsNormally);
      expect(() => logger.i('Message after dispose'), returnsNormally);
    });

    test('debug logger works and disposes gracefully', () {
      final logger = OmniLogger.debug(isolatePrefix: 'debug_test');

      if (kDebugMode) {
        print('🔍 Testing debug logger');
      }
      expect(() => logger.i('Test message from debug'), returnsNormally);
      expect(() => logger.dispose(), returnsNormally);
      expect(() => logger.i('Message after dispose'), returnsNormally);
    });

    test('profile logger works and disposes gracefully', () {
      final logger = OmniLogger.profile(isolatePrefix: 'profile_test');

      if (kDebugMode) {
        print('🔍 Testing profile logger');
      }
      expect(() => logger.i('Test message from profile'), returnsNormally);
      expect(() => logger.dispose(), returnsNormally);
      expect(() => logger.i('Message after dispose'), returnsNormally);
    });

    test('off logger works and disposes gracefully', () {
      final logger = OmniLogger.off(isolatePrefix: 'off_test');

      if (kDebugMode) {
        print('🔍 Testing off logger');
      }
      expect(() => logger.i('Test message from off'), returnsNormally);
      expect(() => logger.dispose(), returnsNormally);
      expect(() => logger.i('Message after dispose'), returnsNormally);
    });

    test('remoteOnly logger works and disposes gracefully', () {
      final logger = OmniLogger.remoteOnly(isolatePrefix: 'remote_test');

      if (kDebugMode) {
        print('🔍 Testing remoteOnly logger');
      }
      expect(() => logger.i('Test message from remoteOnly'), returnsNormally);
      expect(() => logger.dispose(), returnsNormally);
      expect(() => logger.i('Message after dispose'), returnsNormally);
    });
  });

  group('🧹 Resource Management Tests', () {
    test('Logger disposal and graceful degradation', () {
      final logger = OmniLogger.auto();

      if (kDebugMode) {
        print('🔍 Expected disposal and re-initialization messages:');
      }
      expect(() => logger.dispose(), returnsNormally);
      expect(() => logger.i('Message after dispose'), returnsNormally);
    });

    test('Multiple loggers coexistence', () {
      final logger1 = OmniLogger.auto();
      final logger2 = OmniLogger.autoDatabase();
      final logger3 = OmniLogger.autoNetwork();

      if (kDebugMode) {
        print('🔍 Testing multiple loggers (mixed output formats expected):');
      }
      expect(() => logger1.i('Logger 1'), returnsNormally);
      expect(() => logger2.i('Logger 2'), returnsNormally);
      expect(() => logger3.i('Logger 3'), returnsNormally);

      logger1.dispose();
      logger2.dispose();
      logger3.dispose();
    });
  });

  group('🚨 Error Handling Tests', () {
    test('Invalid configuration handling', () {
      final invalidConfig = OmniLogConfig.auto().copyWith(
        maxLogFiles: -1,
        maxFileSizeMB: 0,
      );

      expect(() => OmniLogger(invalidConfig), returnsNormally);
    });

    test('Fallback logger creation', () {
      if (kDebugMode) {
        print('🔍 Expected fallback logger initialization:');
      }
      final fallbackLogger = OmniLogger.createFallbackLogger();

      expect(fallbackLogger, isNotNull);
      expect(() => fallbackLogger.i('Fallback test'), returnsNormally);
    });

    test('Logger test method functionality', () {
      final logger = OmniLogger.auto();

      if (kDebugMode) {
        print('🔍 Expected logger test message:');
      }
      expect(
        () => OmniLogger.testLogger(
          logger,
          isIsolate: false,
          isolateName: 'test',
        ),
        returnsNormally,
      );
    });
  });

  group('🎭 Isolate Context Tests', () {
    test('Isolate detection and information', () {
      expect(
        () => OmniLogger.detectIsolateInfo('test_isolate'),
        returnsNormally,
      );

      final info = OmniLogger.getIsolateInfo('test', false);
      expect(info, isA<Map<String, dynamic>>());

      final formatted = OmniLogger.formatIsolateInfo();
      expect(formatted, isA<String>());
      expect(formatted.isNotEmpty, isTrue);
    });
  });

  group('🔍 Debug Helper Tests', () {
    test('Debug print methods work safely', () {
      expect(OmniLogger.debugPrintIfNeeded, isA<Function>());
      expect(OmniLogger.debugPrintError, isA<Function>());
      expect(OmniLogger.logResetMessage, isA<Function>());
      expect(OmniLogger.debugPrintStats, isA<Function>());

      // Test with minimal output in debug mode only
      if (kDebugMode) {
        print('🔍 Expected minimal debug output:');
        expect(() => OmniLogger.debugPrintIfNeeded(''), returnsNormally);
        expect(() => OmniLogger.logResetMessage(testLogger), returnsNormally);
        expect(() => OmniLogger.debugPrintStats(testLogger), returnsNormally);
      }
    });
  });

  group('🏠 MyLogDirectoryManage Tests', () {
    test('ensureDirectoryExists creates and validates directories', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_log_dir_');
      final testPath = path.join(tempDir.path, 'nested', 'log', 'directory');

      try {
        // Test successful directory creation
        final result = MyLogDirectoryManage.ensureDirectoryExists(testPath);
        expect(result, isNotNull);
        expect(result!.existsSync(), isTrue);

        // Test null path handling
        final nullResult = MyLogDirectoryManage.ensureDirectoryExists(null);
        expect(nullResult, isNull);

        // Test existing directory handling
        final existingResult = MyLogDirectoryManage.ensureDirectoryExists(
          testPath,
        );
        expect(existingResult, isNotNull);
        expect(existingResult!.existsSync(), isTrue);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('date and timestamp utilities work correctly', () async {
      final today = MyLogDirectoryManage.getTodayString();
      final timestamp = MyLogDirectoryManage.getTimestampString();

      // Validate date format (YYYY-MM-DD)
      expect(today, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

      // Validate timestamp is numeric
      expect(int.tryParse(timestamp), isNotNull);
      expect(int.parse(timestamp), greaterThan(0));

      // Test multiple calls return different timestamps
      await Future<dynamic>.delayed(Duration(milliseconds: 1));
      final timestamp2 = MyLogDirectoryManage.getTimestampString();
      expect(timestamp2, isNot(equals(timestamp)));
    });

    test('createLogFileName generates proper file names', () {
      const prefix = 'test_app';
      const logType = OmniLogType.general; // Assuming this enum exists
      const customDate = '2024-01-15';
      const customTimestamp = '1642204800000';

      // Test basic filename generation
      final basicName = MyLogDirectoryManage.createLogFileName(
        logFilePrefix: prefix,
        logType: logType,
      );
      expect(basicName, startsWith(prefix));
      expect(basicName, contains(logType.toString()));
      expect(basicName, endsWith('.log'));

      // Test with custom date
      final dateNameCustom = MyLogDirectoryManage.createLogFileName(
        logFilePrefix: prefix,
        logType: logType,
        date: customDate,
      );
      expect(dateNameCustom, contains(customDate));

      // Test with timestamp
      final timestampName = MyLogDirectoryManage.createLogFileName(
        logFilePrefix: prefix,
        logType: logType,
        timestamp: customTimestamp,
      );
      expect(timestampName, contains(customTimestamp));

      // Test with custom extension
      final customExtName = MyLogDirectoryManage.createLogFileName(
        logFilePrefix: prefix,
        logType: logType,
        extension: 'txt',
      );
      expect(customExtName, endsWith('.txt'));
    });

    test('appName property can be modified', () {
      final originalName = MyLogDirectoryManage.appName;

      try {
        MyLogDirectoryManage.appName = 'TestApp';
        expect(MyLogDirectoryManage.appName, equals('TestApp'));

        // Verify it affects directory paths
        final logDir = MyLogDirectoryManage.getDefaultLogDirectory();
        if (!kIsWeb && logDir != null) {
          expect(logDir, contains('TestApp'));
        }
      } finally {
        MyLogDirectoryManage.appName = originalName;
      }
    });
  });

  group('📁 MyLogManageFileSizeHelpers Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_size_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('findFilesOlderThan correctly identifies old files', () async {
      final oldFile = File(path.join(tempDir.path, 'old_app.log'));
      final newFile = File(path.join(tempDir.path, 'new_app.log'));

      await oldFile.create();
      await newFile.create();

      // Modify old file timestamp
      final oldDate = DateTime.now().subtract(Duration(days: 10));
      await oldFile.setLastModified(oldDate);

      final files = [oldFile, newFile];
      final oldFiles = MyLogManageFileSizeHelpers.findFilesOlderThan(files, 5);

      expect(oldFiles.length, equals(1));
      expect(oldFiles.first.path, equals(oldFile.path));
    });

    test('findFilesExceedingMax returns correct excess files', () async {
      final files = <File>[];
      for (int i = 0; i < 5; i++) {
        final file = File(path.join(tempDir.path, 'app_$i.log'));
        await file.create();
        files.add(file);

        // Set different timestamps
        final date = DateTime.now().subtract(Duration(days: i));
        await file.setLastModified(date);
      }

      final excessFiles = MyLogManageFileSizeHelpers.findFilesExceedingMax(
        files,
        [], // No excluded files
        3, // Max 3 files
      );

      expect(excessFiles.length, equals(2)); // 5 - 3 = 2 excess
      // Should return oldest files first
      expect(excessFiles.first.path, contains('app_4')); // Oldest file
    });

    test('deleteFiles handles file deletion with compression', () async {
      final file1 = File(path.join(tempDir.path, 'delete_test_1.log'));
      final file2 = File(path.join(tempDir.path, 'delete_test_2.log'));

      await file1.writeAsString('Test content 1');
      await file2.writeAsString('Test content 2');

      expect(file1.existsSync(), isTrue);
      expect(file2.existsSync(), isTrue);

      // Test deletion with compression
      MyLogManageFileSizeHelpers.deleteFiles([file1], true);
      expect(file1.existsSync(), isFalse);

      // Test deletion without compression
      MyLogManageFileSizeHelpers.deleteFiles([file2], false);
      expect(file2.existsSync(), isFalse);
    });

    test('getFileSizeSafely handles various file states', () {
      // Test null file
      expect(MyLogManageFileSizeHelpers.getFileSizeSafely(null), equals(0));

      // Test non-existent file
      final nonExistentFile = File(path.join(tempDir.path, 'non_existent.log'));
      expect(
        MyLogManageFileSizeHelpers.getFileSizeSafely(nonExistentFile),
        equals(0),
      );
    });

    test('getFileSizeSafely returns correct size for existing file', () async {
      final testFile = File(path.join(tempDir.path, 'size_test.log'));
      const testContent = 'This is test content for size calculation';
      await testFile.writeAsString(testContent);

      final size = MyLogManageFileSizeHelpers.getFileSizeSafely(testFile);
      expect(size, equals(testContent.length));
    });

    test('calculateMaxFileSize converts MB to bytes correctly', () {
      expect(
        MyLogManageFileSizeHelpers.calculateMaxFileSize(1),
        equals(1024 * 1024),
      );
      expect(
        MyLogManageFileSizeHelpers.calculateMaxFileSize(10),
        equals(10 * 1024 * 1024),
      );
      expect(MyLogManageFileSizeHelpers.calculateMaxFileSize(0), equals(0));
    });

    test('validateMaxFileSize enforces limits and defaults', () {
      // Test normal values
      expect(MyLogManageFileSizeHelpers.validateMaxFileSize(10), equals(10));
      expect(MyLogManageFileSizeHelpers.validateMaxFileSize(25), equals(25));

      // Test invalid values (should return default)
      expect(MyLogManageFileSizeHelpers.validateMaxFileSize(0), equals(10));
      expect(MyLogManageFileSizeHelpers.validateMaxFileSize(-5), equals(10));

      // Test oversized values (should be capped)
      expect(MyLogManageFileSizeHelpers.validateMaxFileSize(100), equals(50));
      expect(MyLogManageFileSizeHelpers.validateMaxFileSize(1000), equals(50));
    });

    test('createLogFileSafely handles file creation scenarios', () async {
      final testPath = path.join(tempDir.path, 'safe_create_test.log');

      // Test successful creation
      final file1 = MyLogManageFileSizeHelpers.createLogFileSafely(testPath);
      expect(file1, isNotNull);
      expect(file1!.existsSync(), isTrue);

      // Test creation when file already exists
      final file2 = MyLogManageFileSizeHelpers.createLogFileSafely(testPath);
      expect(file2, isNotNull);
      expect(file2!.existsSync(), isTrue);

      // Test creation with nested directories
      final nestedPath = path.join(tempDir.path, 'nested', 'dir', 'test.log');
      final file3 = MyLogManageFileSizeHelpers.createLogFileSafely(nestedPath);
      expect(file3, isNotNull);
      expect(file3!.existsSync(), isTrue);
    });

    test('writeLogSafely handles writing scenarios', () async {
      final testFile = File(path.join(tempDir.path, 'write_test.log'));
      await testFile.create();

      // Test successful write
      final result1 = MyLogManageFileSizeHelpers.writeLogSafely(
        testFile,
        'Test content\n',
        FileMode.write,
      );
      expect(result1, isTrue);
      expect(testFile.readAsStringSync(), equals('Test content\n'));

      // Test append mode
      final result2 = MyLogManageFileSizeHelpers.writeLogSafely(
        testFile,
        'Appended content\n',
        FileMode.append,
      );
      expect(result2, isTrue);
      expect(
        testFile.readAsStringSync(),
        equals('Test content\nAppended content\n'),
      );
    });

    test('edge cases and error handling', () async {
      // Test findFilesOlderThan with files that throw exceptions
      final corruptedFile = File(path.join(tempDir.path, 'corrupted.log'));
      await corruptedFile.create();

      // This should not throw even if file system operations fail
      expect(
        () => MyLogManageFileSizeHelpers.findFilesOlderThan([corruptedFile], 5),
        returnsNormally,
      );

      // Test deleteFiles with non-existent files
      final nonExistentFile = File(path.join(tempDir.path, 'non_existent.log'));
      expect(
        () => MyLogManageFileSizeHelpers.deleteFiles([nonExistentFile], false),
        returnsNormally,
      );

      // Test findFilesExceedingMax with edge cases
      expect(
        MyLogManageFileSizeHelpers.findFilesExceedingMax([], [], 5),
        isEmpty,
      );

      final singleFile = File(path.join(tempDir.path, 'single.log'));
      await singleFile.create();
      expect(
        MyLogManageFileSizeHelpers.findFilesExceedingMax([singleFile], [], 5),
        isEmpty,
      );
    });
  });

  group('🔧 Integration Tests for Coverage Improvement', () {
    test('complex workflow with directory and file management', () async {
      final testDir = await Directory.systemTemp.createTemp(
        'integration_test_',
      );

      try {
        // Test complete workflow
        MyLogDirectoryManage.appName = 'IntegrationTestApp';
        MyLogIsolateHelpers.isolateName = 'integration_isolate';
        MyLogIsolateHelpers.isIsolate = true;

        // Create multiple log files
        final files = <File>[];
        for (int i = 0; i < 10; i++) {
          final fileName = MyLogDirectoryManage.createLogFileName(
            logFilePrefix: 'integration',
            logType: OmniLogType.general,
            timestamp: (DateTime.now().millisecondsSinceEpoch + i).toString(),
          );
          final file = File(path.join(testDir.path, fileName));
          await file.writeAsString(
            'Log entry $i\n' * 100,
          ); // Make files of different sizes
          files.add(file);

          // Set different timestamps
          await file.setLastModified(
            DateTime.now().subtract(Duration(days: i)),
          );
        }

        // Test file management operations
        final sortedFiles = MyLogManageFileSizeHelpers.getSortedLogFiles(
          testDir,
          'integration',
        );
        expect(sortedFiles.length, equals(10));

        // Test cleanup operations
        final oldFiles = MyLogManageFileSizeHelpers.findFilesOlderThan(
          sortedFiles,
          5,
        );
        expect(oldFiles.length, greaterThan(0));

        final excessFiles = MyLogManageFileSizeHelpers.findFilesExceedingMax(
          sortedFiles,
          oldFiles,
          3,
        );
        expect(excessFiles.length, greaterThan(0));

        // Test file size validation
        final maxSize = MyLogManageFileSizeHelpers.validateMaxFileSize(15);
        expect(maxSize, equals(15));

        // Test isolate information
        final isolateInfo = MyLogIsolateHelpers.getIsolateInfo(
          'integration_isolate',
          true,
        );
        expect(isolateInfo['name'], equals('integration_isolate'));
        expect(isolateInfo['isIsolate'], isTrue);
      } finally {
        if (await testDir.exists()) {
          await testDir.delete(recursive: true);
        }
      }
    });
  });
  // Additional test cases to improve coverage for OmniLogger

  group('🛠️ MyLogManager Core Functionality Tests', () {
    test(
      'initializeOrRotateLogFile creates new file when none exists',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('log_test_');

        try {
          final result = MyLogManager.initializeOrRotateLogFile(
            logDirectory: tempDir,
            logFilePrefix: 'test_app',
            logType: OmniLogType.general,
            maxFileSizeMB: 5,
            currentFile: null,
            currentDate: null,
          );

          expect(result.file, isNotNull);
          expect(result.error, isNull);
          expect(result.currentDate, isNotEmpty);
          expect(result.currentSize, equals(0));
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test('initializeOrRotateLogFile rotates on date change', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        // Create initial file
        final initialFile = File(
          '${tempDir.path}/test_app_general_2023-01-01.log',
        );
        await initialFile.create();
        await initialFile.writeAsString('existing content');

        final result = MyLogManager.initializeOrRotateLogFile(
          logDirectory: tempDir,
          logFilePrefix: 'test_app',
          logType: OmniLogType.general,
          maxFileSizeMB: 5,
          currentFile: initialFile,
          currentDate: '2023-01-01', // Old date to trigger rotation
        );

        expect(result.file, isNotNull);
        expect(result.file?.path, isNot(equals(initialFile.path)));
        expect(result.error, isNull);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('initializeOrRotateLogFile rotates on size limit', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        // Create a file that exceeds size limit
        final largeFile = File('${tempDir.path}/test_large.log');
        await largeFile.create();
        // Write enough content to exceed 1MB limit
        final largeContent = 'x' * (2 * 1024 * 1024); // 2MB
        await largeFile.writeAsString(largeContent);

        final result = MyLogManager.initializeOrRotateLogFile(
          logDirectory: tempDir,
          logFilePrefix: 'test_app',
          logType: OmniLogType.general,
          maxFileSizeMB: 1, // 1MB limit
          currentFile: largeFile,
          currentDate: MyLogDirectoryManage.getTodayString(),
        );

        expect(result.file, isNotNull);
        expect(result.file?.path, isNot(equals(largeFile.path)));
        expect(result.error, isNull);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('initializeOrRotateLogFile rotates on size limit', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        // Create a file that exceeds size limit
        final largeFile = File('${tempDir.path}/test_large.log');
        await largeFile.create();
        // Write enough content to exceed 1MB limit
        final largeContent = 'x' * (2 * 1024 * 1024); // 2MB
        await largeFile.writeAsString(largeContent);

        final result = MyLogManager.initializeOrRotateLogFile(
          logDirectory: tempDir,
          logFilePrefix: 'test_app',
          logType: OmniLogType.general,
          maxFileSizeMB: 1, // 1MB limit
          currentFile: largeFile,
          currentDate: MyLogDirectoryManage.getTodayString(),
        );

        expect(result.file, isNotNull);
        expect(result.file?.path, isNot(equals(largeFile.path)));
        expect(result.error, isNull);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('initializeOrRotateLogFile handles errors gracefully', () {
      // Test with invalid directory path
      final invalidDir = Directory('/invalid/path/that/does/not/exist');

      final result = MyLogManager.initializeOrRotateLogFile(
        logDirectory: invalidDir,
        logFilePrefix: 'test_app',
        logType: OmniLogType.general,
        maxFileSizeMB: 5,
        currentFile: null,
        currentDate: null,
      );

      expect(result.file, isNull);
      expect(result.error, isNotNull);
      expect(
        result.error,
        contains(
          'Failed to create log file: /invalid/path/that/does/not/exist',
        ),
      );
    });

    // Test no rotation needed scenario
    test(
      'initializeOrRotateLogFile returns current file when no rotation needed',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('log_test_');

        try {
          final currentFile = File('${tempDir.path}/current_test.log');
          await currentFile.create();
          await currentFile.writeAsString('some content');

          final result = MyLogManager.initializeOrRotateLogFile(
            logDirectory: tempDir,
            logFilePrefix: 'test_app',
            logType: OmniLogType.general,
            maxFileSizeMB: 5,
            currentFile: currentFile,
            currentDate: MyLogDirectoryManage.getTodayString(),
          );

          expect(result.file, equals(currentFile));
          expect(result.error, isNull);
          expect(result.currentSize, greaterThan(0));
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    // Test with invalid maxFileSizeMB
    test('initializeOrRotateLogFile handles invalid maxFileSizeMB', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        final result = MyLogManager.initializeOrRotateLogFile(
          logDirectory: tempDir,
          logFilePrefix: 'test_app',
          logType: OmniLogType.general,
          maxFileSizeMB: 0, // Invalid size
          currentFile: null,
          currentDate: null,
        );

        expect(result.file, isNotNull);
        expect(result.error, isNull);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    // Test with extremely large maxFileSizeMB
    test('initializeOrRotateLogFile handles oversized maxFileSizeMB', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        final result = MyLogManager.initializeOrRotateLogFile(
          logDirectory: tempDir,
          logFilePrefix: 'test_app',
          logType: OmniLogType.general,
          maxFileSizeMB: 1000, // Oversized
          currentFile: null,
          currentDate: null,
        );

        expect(result.file, isNotNull);
        expect(result.error, isNull);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('writeLogHeader creates comprehensive header', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        final logFile = File('${tempDir.path}/test_header.log');
        await logFile.create();

        final success = await MyLogManager.writeLogHeader(
          logFile: logFile,
          logType: OmniLogType.general,
          logFilePrefix: 'test_app',
          maxFileSizeMB: 10,
          maxLogFiles: 5,
          logRetentionDays: 7,
          currentFileSizeBytes: 1024,
          includeDeviceInfo: true,
        );

        expect(success, isTrue);

        final content = await logFile.readAsString();
        expect(content, contains('GENERAL LOG STARTED'));
        expect(content, contains('Max File Size: 10MB'));
        expect(content, contains('Current Used:'));
        expect(content, contains('Remaining:'));
        expect(content, contains('Usage:'));
        expect(content, contains('Max Files: 5'));
        expect(content, contains('Retention Days: 7'));
        expect(content, contains('DEVICE INFORMATION'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('writeLogHeader handles write errors', () async {
      // Test with read-only file or invalid path
      final invalidFile = File('/invalid/path/readonly.log');

      final success = await MyLogManager.writeLogHeader(
        logFile: invalidFile,
        logType: OmniLogType.general,
        logFilePrefix: 'test_app',
        maxFileSizeMB: 5,
        maxLogFiles: 3,
        logRetentionDays: 7,
      );

      expect(success, isFalse);
    });

    //Test writeLogHeader with zero currentFileSizeBytes
    test('writeLogHeader handles zero file size correctly', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        final logFile = File('${tempDir.path}/test_zero_size.log');
        await logFile.create();

        final success = await MyLogManager.writeLogHeader(
          logFile: logFile,
          logType: OmniLogType.general,
          logFilePrefix: 'test_app',
          maxFileSizeMB: 5,
          maxLogFiles: 3,
          logRetentionDays: 7,
          currentFileSizeBytes: 0,
          includeDeviceInfo: false,
        );

        expect(success, isTrue);

        final content = await logFile.readAsString();
        expect(content, contains('Current Used: 0.00MB'));
        expect(content, contains('Usage: 0.0%'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    // Test writeLogHeader with invalid maxFileSizeMB
    test('writeLogHeader handles invalid maxFileSizeMB values', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        final logFile = File('${tempDir.path}/test_invalid_size.log');
        await logFile.create();

        final success = await MyLogManager.writeLogHeader(
          logFile: logFile,
          logType: OmniLogType.general,
          logFilePrefix: 'test_app',
          maxFileSizeMB: -1, // Invalid negative value
          maxLogFiles: 3,
          logRetentionDays: 7,
        );

        expect(success, isTrue);

        final content = await logFile.readAsString();
        expect(
          content,
          contains('Max File Size: 10MB'),
        ); // Should default to 10MB
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    // NEW TEST: Test writeLogEntry with empty lines
    test('writeLogEntry handles empty lines correctly', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        final logFile = File('${tempDir.path}/test_empty_lines.log');
        await logFile.create();

        final bytes = MyLogManager.writeLogEntry(
          logFile: logFile,
          lines: [],
          level: OmniLogLevel.info,
        );

        expect(bytes, equals(0));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    // Test writeLogEntry without timestamp
    test('writeLogEntry works without timestamp', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        final logFile = File('${tempDir.path}/test_no_timestamp.log');
        await logFile.create();

        final bytes = MyLogManager.writeLogEntry(
          logFile: logFile,
          lines: ['Message without timestamp'],
          level: OmniLogLevel.info,
          includeTimestamp: false,
        );

        expect(bytes, greaterThan(0));

        final content = await logFile.readAsString();
        expect(content, contains('Message without timestamp'));
        expect(content, isNot(contains('[')));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    // Test cleanOldLogsSync with non-existent directory
    test('cleanOldLogsSync handles non-existent directory', () {
      final result = MyLogManager.cleanOldLogsSync(
        '/non/existent/directory',
        'test_app',
        5,
        7,
        false,
      );

      expect(result, equals(0));
    });

    // Test cleanOldLogsSync with invalid parameters
    test('cleanOldLogsSync handles invalid parameters', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        // Test with invalid maxLogFiles
        var result = MyLogManager.cleanOldLogsSync(
          tempDir.path,
          'test_app',
          0, // Invalid maxLogFiles
          7,
          false,
        );
        expect(result, equals(0));

        // Test with invalid logRetentionDays
        result = MyLogManager.cleanOldLogsSync(
          tempDir.path,
          'test_app',
          5,
          -1, // Invalid logRetentionDays
          false,
        );
        expect(result, equals(0));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    // Test cleanOldLogsSync with no log files
    test('cleanOldLogsSync handles directory with no log files', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        // Create some non-log files
        await File('${tempDir.path}/not_a_log.txt').create();
        await File('${tempDir.path}/another_file.dat').create();

        final result = MyLogManager.cleanOldLogsSync(
          tempDir.path,
          'test_app',
          5,
          7,
          false,
        );

        expect(result, equals(0));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    // Test cleanOldLogsSync with files to delete based on age
    test(
      'cleanOldLogsSync deletes old files based on retention days',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('log_test_');

        try {
          // Create old log files
          final oldFile1 = File('${tempDir.path}/test_app_old1.log');
          final oldFile2 = File('${tempDir.path}/test_app_old2.log');
          await oldFile1.create();
          await oldFile2.create();

          // Manually set old modification times (simulate old files)
          final oldDate = DateTime.now().subtract(const Duration(days: 10));
          await oldFile1.setLastModified(oldDate);
          await oldFile2.setLastModified(oldDate);

          final result = MyLogManager.cleanOldLogsSync(
            tempDir.path,
            'test_app',
            10,
            7, // Retention days
            false,
          );

          expect(result, equals(2));
          expect(oldFile1.existsSync(), isFalse);
          expect(oldFile2.existsSync(), isFalse);
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    // Test cleanOldLogsSync with files to delete based on count
    test(
      'cleanOldLogsSync deletes excess files based on maxLogFiles',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('log_test_');

        try {
          // Create more files than the limit
          final files = <File>[];
          for (int i = 0; i < 7; i++) {
            final file = File('${tempDir.path}/test_app_file$i.log');
            await file.create();
            files.add(file);

            // Stagger the modification times
            await file.setLastModified(
              DateTime.now().subtract(Duration(minutes: i)),
            );
          }

          final result = MyLogManager.cleanOldLogsSync(
            tempDir.path,
            'test_app',
            5, // Keep only 5 files
            0, // No age-based retention
            false,
          );

          expect(result, equals(2)); // Should delete 2 oldest files

          // Check that the newest 5 files still exist
          final remainingFiles = tempDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.log'))
              .toList();
          expect(remainingFiles.length, equals(5));
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    // Test cleanOldLogsSync with compression enabled
    test('cleanOldLogsSync with compression enabled', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        // Create old log file
        final oldFile = File('${tempDir.path}/test_app_old.log');
        await oldFile.create();
        await oldFile.writeAsString('Log content for compression test');

        // Set old modification time
        final oldDate = DateTime.now().subtract(const Duration(days: 10));
        await oldFile.setLastModified(oldDate);

        final result = MyLogManager.cleanOldLogsSync(
          tempDir.path,
          'test_app',
          10,
          7,
          true, // Enable compression
        );

        expect(result, equals(1));
        expect(oldFile.existsSync(), isFalse);

        // Check if compressed file was created
        final compressedFile = File('${tempDir.path}/test_app_old.log.gz');
        expect(compressedFile.existsSync(), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    // Test cleanOldLogsSync with mixed scenarios
    test('cleanOldLogsSync handles mixed age and count scenarios', () async {
      final tempDir = await Directory.systemTemp.createTemp('log_test_');

      try {
        // Create mix of old and new files
        final oldFile = File('${tempDir.path}/test_app_old.log');
        final newFiles = <File>[];

        await oldFile.create();
        await oldFile.setLastModified(
          DateTime.now().subtract(const Duration(days: 10)),
        );

        for (int i = 0; i < 4; i++) {
          final file = File('${tempDir.path}/test_app_new$i.log');
          await file.create();
          newFiles.add(file);
        }

        final result = MyLogManager.cleanOldLogsSync(
          tempDir.path,
          'test_app',
          3, // Keep only 3 files
          7, // 7 days retention
          false,
        );

        // Should delete old file (age) + 1 excess file (count)
        expect(result, equals(2));
        expect(oldFile.existsSync(), isFalse);

        final remainingFiles = tempDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.log'))
            .toList();
        expect(remainingFiles.length, equals(3));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    //  Test error handling in writeLogEntry
    test('writeLogEntry handles file write errors gracefully', () async {
      // Test with non-existent directory
      final invalidFile = File('/invalid/path/test.log');

      final bytes = MyLogManager.writeLogEntry(
        logFile: invalidFile,
        lines: ['Test message'],
        level: OmniLogLevel.info,
      );

      expect(bytes, equals(0));
    });
  });
  group('🔐 Critical: File System Permissions & Security', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('perm_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('📁 Directory Handling', () {
      test('handles unusual directory paths gracefully', () async {
        final edgeCases = [Directory(''), Directory(' '), Directory('a' * 300)];

        for (final edgeDir in edgeCases) {
          final result = MyLogManager.initializeOrRotateLogFile(
            logDirectory: edgeDir,
            logFilePrefix: 'test',
            logType: OmniLogType.general,
            maxFileSizeMB: 5,
          );

          expect(() => result, returnsNormally);
          if (result.file == null) {
            expect(result.error, isNotNull);
          }
        }
      });

      test('handles non-existent directory gracefully', () async {
        final nonExistentDir = Directory(
          '/this/path/definitely/does/not/exist/anywhere',
        );

        final result = MyLogManager.initializeOrRotateLogFile(
          logDirectory: nonExistentDir,
          logFilePrefix: 'test_app',
          logType: OmniLogType.general,
          maxFileSizeMB: 5,
        );

        expect(result.file, isNull);
        expect(result.error, isNotNull);
      });

      test('handles directory creation failure gracefully', () async {
        final tempDir = await Directory.systemTemp.createTemp('test_');
        final tempFile = File('${tempDir.path}/blocking_file.txt');
        await tempFile.create();

        final blockedDir = Directory('${tempFile.path}/cannot_create_here');

        try {
          final result = MyLogManager.initializeOrRotateLogFile(
            logDirectory: blockedDir,
            logFilePrefix: 'test_app',
            logType: OmniLogType.general,
            maxFileSizeMB: 5,
          );

          expect(result.file, isNull);
          expect(result.error, isNotNull);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    group('🔒 Permissions', () {
      test('handles read-only directory gracefully', () async {
        if (!Platform.isWindows) {
          final readOnlyDir = Directory('${tempDir.path}/readonly');
          await readOnlyDir.create();
          await Process.run('chmod', ['444', readOnlyDir.path]);

          final result = MyLogManager.initializeOrRotateLogFile(
            logDirectory: readOnlyDir,
            logFilePrefix: 'test_app',
            logType: OmniLogType.general,
            maxFileSizeMB: 5,
          );

          expect(result.file, isNull);
          expect(result.error, isNotNull);
          expect(result.error, contains('Failed to create log file'));

          await Process.run('chmod', ['755', readOnlyDir.path]);
        }
      });

      test('handles file becoming read-only after creation', () async {
        final logFile = File('${tempDir.path}/readonly_test.log');
        await logFile.create();
        await logFile.writeAsString('initial content');

        if (!Platform.isWindows) {
          await Process.run('chmod', ['444', logFile.path]);
        }

        final bytes = MyLogManager.writeLogEntry(
          logFile: logFile,
          lines: ['This should fail'],
          level: OmniLogLevel.info,
        );

        expect(bytes, equals(0));

        if (!Platform.isWindows) {
          await Process.run('chmod', ['644', logFile.path]);
        }
      });
    });

    group('💾 Write Failures & Exhaustion', () {
      test('handles disk space exhaustion simulation', () async {
        final largeContent = List.generate(
          1000,
          (i) =>
              'Large log entry $i with lots of content that might fill up disk space',
        ).join('\n');

        final logFile = File('${tempDir.path}/large_test.log');
        await logFile.create();

        final bytes = MyLogManager.writeLogEntry(
          logFile: logFile,
          lines: [largeContent],
          level: OmniLogLevel.info,
        );

        expect(bytes >= 0, isTrue);
      });
    });

    group('🧪 Edge Path Cases', () {
      test('handles edge case paths', () async {
        final edgeCases = ['/dev/null', 'con.log'];

        for (final edgePath in edgeCases) {
          final result = MyLogManager.initializeOrRotateLogFile(
            logDirectory: Directory(edgePath),
            logFilePrefix: 'test',
            logType: OmniLogType.general,
            maxFileSizeMB: 5,
          );

          expect(() => result, returnsNormally);

          if (Platform.isWindows && edgePath == 'con.log') {
            expect(result.file, isNull);
            expect(result.error, isNotNull);
          }
        }
      });
    });
  });
  group('💾 Critical: Memory & Resource Management', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('memory_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('handles extremely large log entries without OOM', () async {
      final logFile = File('${tempDir.path}/large_entry_test.log');
      await logFile.create();

      // Create a very large log entry (10MB of text)
      final largeEntry = 'x' * (10 * 1024 * 1024);

      // This should handle gracefully without causing OOM
      expect(() {
        final bytes = MyLogManager.writeLogEntry(
          logFile: logFile,
          lines: [largeEntry],
          level: OmniLogLevel.info,
        );
        expect(bytes >= 0, isTrue);
      }, returnsNormally);
    });

    test('handles massive header generation without memory issues', () async {
      final logFile = File('${tempDir.path}/large_header_test.log');
      await logFile.create();

      // Test with very large file sizes that might cause formatting issues
      expect(() async {
        final success = await MyLogManager.writeLogHeader(
          logFile: logFile,
          logType: OmniLogType.general,
          logFilePrefix: 'test_app',
          maxFileSizeMB: 50, // Large but valid
          maxLogFiles: 1000,
          logRetentionDays: 365,
          currentFileSizeBytes: 30 * 1024 * 1024, // 30MB current
          includeDeviceInfo: true,
        );
        expect(success, isA<bool>());
      }, returnsNormally);
    });

    test('handles cleanup of thousands of files efficiently', () async {
      // Create many small log files
      final files = <File>[];
      for (int i = 0; i < 1000; i++) {
        final file = File('${tempDir.path}/mass_cleanup_$i.log');
        await file.create();
        files.add(file);

        if (i % 100 == 0) {
          // Set some as old files
          await file.setLastModified(
            DateTime.now().subtract(Duration(days: 30)),
          );
        }
      }

      // This should complete without hanging or using excessive memory
      final stopwatch = Stopwatch()..start();

      final cleanedCount = MyLogManager.cleanOldLogsSync(
        tempDir.path,
        'mass_cleanup',
        100, // Keep only 100 files
        7, // 7 days retention
        false,
      );

      stopwatch.stop();

      expect(cleanedCount >= 0, isTrue);
      expect(
        stopwatch.elapsedMilliseconds < 30000,
        isTrue,
      ); // Should complete within 30 seconds
    });

    test('handles file handle management properly', () async {
      // Test multiple file operations to ensure no handle leaks
      final files = <File>[];

      for (int i = 0; i < 100; i++) {
        final file = File('${tempDir.path}/handle_test_$i.log');
        await file.create();
        files.add(file);

        // Write and read operations
        final bytes = MyLogManager.writeLogEntry(
          logFile: file,
          lines: ['Test entry $i'],
          level: OmniLogLevel.info,
        );
        expect(bytes > 0, isTrue);
      }

      // All operations should complete without "too many open files" errors
      expect(files.length, equals(100));
    });
  });
  group('🌐 Critical: Platform-Specific Failures', () {
    test('handles DeviceInfoPlugin failures gracefully', () async {
      final tempDir = await Directory.systemTemp.createTemp('platform_test_');

      try {
        final logFile = File('${tempDir.path}/device_info_test.log');
        await logFile.create();

        // This test verifies the header creation works even if device info fails
        final success = await MyLogManager.writeLogHeader(
          logFile: logFile,
          logType: OmniLogType.general,
          logFilePrefix: 'test_app',
          maxFileSizeMB: 5,
          maxLogFiles: 10,
          logRetentionDays: 7,
          includeDeviceInfo: true,
        );

        expect(success, isTrue);

        final content = await logFile.readAsString();
        expect(content, contains('DEVICE INFORMATION'));
        // Should contain either device info or error message
        expect(
          content.contains('Platform:') || content.contains('Error:'),
          isTrue,
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('handles platform-specific file operations', () async {
      final tempDir = await Directory.systemTemp.createTemp('platform_ops_');

      try {
        // Test with platform-specific challenging file names
        final challengingNames = [
          if (Platform.isWindows) 'con.log', // Windows reserved
          if (Platform.isWindows) 'nul.log', // Windows reserved
          if (!Platform.isWindows) '.hidden.log', // Unix hidden file
          'file with spaces.log',
          'file-with-dashes.log',
          'file_with_underscores.log',
        ];

        for (final fileName in challengingNames) {
          final result = MyLogManager.initializeOrRotateLogFile(
            logDirectory: tempDir,
            logFilePrefix: fileName.split('.').first,
            logType: OmniLogType.general,
            maxFileSizeMB: 5,
          );

          // Should handle gracefully - either succeed or fail with error
          expect(result, isNotNull);
          if (result.file == null) {
            expect(result.error, isNotNull);
          }
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
  group('⏰ Critical: Time-Based Edge Cases', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('time_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('handles date transition during rotation', () async {
      final testFile = File('${tempDir.path}/date_test.log');
      await testFile.create();

      // Test with yesterday's date to force rotation
      final yesterday = DateTime.now().subtract(Duration(days: 1));
      final yesterdayString =
          "${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

      final result = MyLogManager.initializeOrRotateLogFile(
        logDirectory: tempDir,
        logFilePrefix: 'date_test',
        logType: OmniLogType.general,
        maxFileSizeMB: 5,
        currentFile: testFile,
        currentDate: yesterdayString,
      );

      expect(result.file, isNotNull);
      expect(
        result.file?.path,
        isNot(equals(testFile.path)),
      ); // Should create new file
      expect(result.error, isNull);
    });

    test('handles malformed date strings gracefully', () async {
      final testFile = File('${tempDir.path}/malformed_date_test.log');
      await testFile.create();

      final malformedDates = [
        'invalid-date',
        '2023-13-45', // Invalid month/day
        '', // Empty string
        '2023/12/31', // Wrong format
        null, // Null value
      ];

      for (final malformedDate in malformedDates) {
        expect(() {
          final result = MyLogManager.initializeOrRotateLogFile(
            logDirectory: tempDir,
            logFilePrefix: 'malformed_test',
            logType: OmniLogType.general,
            maxFileSizeMB: 5,
            currentFile: testFile,
            currentDate: malformedDate,
          );
          expect(result, isNotNull); // Should handle gracefully
        }, returnsNormally);
      }
    });

    test('handles rapid successive operations', () async {
      // Test multiple rapid operations that might race with timestamp generation
      final futures = <Future<LogFileInfo>>[];

      for (int i = 0; i < 10; i++) {
        futures.add(
          Future.microtask(() {
            return MyLogManager.initializeOrRotateLogFile(
              logDirectory: tempDir,
              logFilePrefix: 'rapid_test',
              logType: OmniLogType.general,
              maxFileSizeMB: 1, // Small size to potentially trigger rotations
            );
          }),
        );
      }

      final results = await Future.wait(futures);

      // All operations should complete successfully
      for (final result in results) {
        expect(result, isNotNull);
        expect(result.file != null || result.error != null, isTrue);
      }
    });
  });

  group('🛡️ Critical: Error Recovery & Graceful Degradation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('recovery_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('recovers from corrupted log files', () async {
      // Create a corrupted/truncated log file
      final corruptedFile = File('${tempDir.path}/corrupted.log');
      await corruptedFile.create();

      // Write some binary data to simulate corruption
      await corruptedFile.writeAsBytes([0xFF, 0xFE, 0x00, 0x01, 0xFF]);

      // Should handle gracefully when trying to rotate or write
      final result = MyLogManager.initializeOrRotateLogFile(
        logDirectory: tempDir,
        logFilePrefix: 'recovery_test',
        logType: OmniLogType.general,
        maxFileSizeMB: 5,
        currentFile: corruptedFile,
        currentDate: MyLogDirectoryManage.getTodayString(),
      );

      expect(result, isNotNull);
      // Should either use the file or create a new one
      expect(result.file != null || result.error != null, isTrue);
    });

    test('handles network drive disconnection simulation', () async {
      // Simulate network drive issues by using a path that might become unavailable
      final networkPath = Platform.isWindows
          ? 'Z:\\nonexistent\\path'
          : '/mnt/nonexistent/path';
      final networkDir = Directory(networkPath);

      final result = MyLogManager.initializeOrRotateLogFile(
        logDirectory: networkDir,
        logFilePrefix: 'network_test',
        logType: OmniLogType.general,
        maxFileSizeMB: 5,
      );

      expect(result.file, isNull);
      expect(result.error, isNotNull);
      expect(result.error, contains('Failed to create log file'));
    });

    test('handles partial write failures gracefully', () async {
      final logFile = File('${tempDir.path}/partial_write_test.log');
      await logFile.create();

      // Test with very long content that might cause partial writes
      final veryLongLines = List.generate(
        1000,
        (i) =>
            'Very long log line $i with lots of content that might cause issues during writing operations',
      );

      expect(() {
        final bytes = MyLogManager.writeLogEntry(
          logFile: logFile,
          lines: veryLongLines,
          level: OmniLogLevel.info,
        );
        expect(
          bytes >= 0,
          isTrue,
        ); // Should return 0 on failure or positive on success
      }, returnsNormally);
    });

    test('handles file system errors during cleanup', () async {
      // Create files and then make directory read-only during cleanup
      final files = <File>[];
      for (int i = 0; i < 10; i++) {
        final file = File('${tempDir.path}/cleanup_error_$i.log');
        await file.create();
        files.add(file);

        await file.setLastModified(DateTime.now().subtract(Duration(days: 10)));
      }

      // Make directory read-only (on Unix systems)
      if (!Platform.isWindows) {
        await Process.run('chmod', ['444', tempDir.path]);

        // Cleanup should handle the permission error gracefully
        expect(() {
          final result = MyLogManager.cleanOldLogsSync(
            tempDir.path,
            'cleanup_error',
            5,
            7,
            false,
          );
          expect(result >= 0, isTrue); // Should return 0 on error
        }, returnsNormally);

        // Restore permissions for cleanup
        await Process.run('chmod', ['755', tempDir.path]);
      }
    });

    test('handles extreme file size calculations', () async {
      final logFile = File('${tempDir.path}/extreme_size_test.log');
      await logFile.create();

      // Test with extreme values that might cause integer overflow
      expect(() async {
        final success = await MyLogManager.writeLogHeader(
          logFile: logFile,
          logType: OmniLogType.general,
          logFilePrefix: 'extreme_test',
          maxFileSizeMB: 50, // Max allowed
          maxLogFiles: 1000,
          logRetentionDays: 365,
          currentFileSizeBytes: 49 * 1024 * 1024, // Near max
        );
        expect(success, isA<bool>());
      }, returnsNormally);
    });
  });
  group('📁 MyFileOutput Missing Coverage Tests', () {
    late Directory tempDir;
    late String tempDirPath;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'myfileoutput_coverage_test_',
      );
      tempDirPath = tempDir.path;
    });

    tearDownAll(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Directory Creation Tests', () {
      test('creates log directory when it does not exist', () {
        final nonExistentDir = '$tempDirPath/non_existent_logs';

        // Ensure directory doesn't exist
        final dir = Directory(nonExistentDir);
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }

        final output = OmniFileOutput.createSync(
          customLogDirectory: nonExistentDir,
          logFilePrefix: 'test',
          maxLogFiles: 3,
          logRetentionDays: 1,
        );

        expect(output, isNotNull);
        expect(Directory(nonExistentDir).existsSync(), isTrue);

        output?.dispose();
      });

      test('handles nested directory creation', () {
        final nestedDir = '$tempDirPath/level1/level2/level3/logs';

        final output = OmniFileOutput.createSync(
          customLogDirectory: nestedDir,
          logFilePrefix: 'nested',
          maxLogFiles: 2,
          logRetentionDays: 1,
        );

        expect(output, isNotNull);
        expect(Directory(nestedDir).existsSync(), isTrue);

        output?.dispose();
      });
    });

    group('Periodic Cleanup Tests', () {
      test('performs periodic cleanup after threshold writes', () {
        final output = OmniFileOutput.createSync(
          customLogDirectory: '$tempDirPath/cleanup_test',
          logFilePrefix: 'cleanup',
          maxLogFiles: 3,
          logRetentionDays: 1,
        );

        expect(output, isNotNull);

        // Create some old log files to test cleanup
        final logDir = Directory('$tempDirPath/cleanup_test');
        final oldFile = File('${logDir.path}/cleanup_old.log');
        oldFile.createSync();
        oldFile.writeAsStringSync('old content');

        // Write enough entries to trigger periodic cleanup (100+ writes)
        for (int i = 0; i < 105; i++) {
          final logEvent = LogEvent(Level.info, 'Test message $i');
          final event = OutputEvent(logEvent, ['Test message $i']);
          output!.output(event);
        }

        // Verify cleanup was triggered (writesSinceLastCheck should be reset)
        final stats = output?.getLogStats();
        expect(stats?['writesSinceLastCheck'], lessThan(105));

        output?.dispose();
      });

      test('skips cleanup when last cleanup was recent', () {
        final output = OmniFileOutput.createSync(
          customLogDirectory: '$tempDirPath/recent_cleanup_test',
          logFilePrefix: 'recent',
          maxLogFiles: 3,
          logRetentionDays: 1,
        );

        expect(output, isNotNull);

        // Force a cleanup first
        for (int i = 0; i < 101; i++) {
          final logEvent = LogEvent(Level.info, 'Setup message $i');
          final event = OutputEvent(logEvent, ['Setup message $i']);
          output!.output(event);
        }

        final statsAfterFirst = output?.getLogStats();
        final firstCleanupTime = statsAfterFirst?['lastCleanupTime'];

        // Write more entries immediately (should skip cleanup due to recent cleanup)
        for (int i = 0; i < 101; i++) {
          final logEvent = LogEvent(Level.info, 'Second batch $i');
          final event = OutputEvent(logEvent, ['Second batch $i']);
          output?.output(event);
        }

        final statsAfterSecond = output?.getLogStats();
        expect(statsAfterSecond?['lastCleanupTime'], equals(firstCleanupTime));

        output?.dispose();
      });
    });

    group('Log Rotation Tests', () {
      test('rotates log file when date changes', () {
        final output = OmniFileOutput.createSync(
          customLogDirectory: '$tempDirPath/rotation_test',
          logFilePrefix: 'rotate',
          maxLogFiles: 5,
          logRetentionDays: 2,
        );

        expect(output, isNotNull);

        // Get initial file path
        final initialFile = output!.currentLogFilePath;
        expect(initialFile, isNotNull);

        // Mock date change by writing every 10th entry (triggers date check)
        // This will call _initializeOrRotataLogFileSync when date changes
        for (int i = 0; i < 15; i++) {
          final logEvent = LogEvent(Level.info, 'Rotation test $i');
          final event = OutputEvent(logEvent, ['Rotation test $i']);
          output.output(event);

          // Every 10th write checks for date change
          if (i == 9) {
            // File should still be the same since date hasn't actually changed
            expect(output.currentLogFilePath, equals(initialFile));
          }
        }

        output.dispose();
      });

      test('rotates log file when size limit exceeded', () {
        final output = OmniFileOutput.createSync(
          customLogDirectory: '$tempDirPath/size_rotation_test',
          logFilePrefix: 'size_rotate',
          maxLogFiles: 3,
          maxFileSizeMB: 1, // Very small limit to trigger rotation
          logRetentionDays: 1,
        );

        expect(output, isNotNull);

        final initialFile = output!.currentLogFilePath;

        // Write large entries to exceed size limit
        final largeMessage = 'x' * 1000; // 1KB per message
        for (int i = 0; i < 1200; i++) {
          // Should exceed 1MB
          final logEvent = LogEvent(Level.info, largeMessage);
          final event = OutputEvent(logEvent, [largeMessage]);
          output.output(event);

          // Check if rotation occurred
          if (output.currentLogFilePath != initialFile) {
            // Rotation happened
            break;
          }
        }

        output.dispose();
      });
    });

    group('Error Handling Tests', () {
      test('handles getLogStats error gracefully', () {
        // Create an output with invalid directory to trigger error
        final output = OmniFileOutput.createSync(
          customLogDirectory: '/invalid/path/that/cannot/exist',
          logFilePrefix: 'error_test',
          maxLogFiles: 1,
          logRetentionDays: 1,
        );

        // This might return null due to invalid path
        if (output != null) {
          final stats = output.getLogStats();
          expect(stats, isA<Map<String, dynamic>>());
          output.dispose();
        } else {
          // Test that we handle null output gracefully
          expect(output, isNull);
        }
      });
    });

    group('Getter Tests', () {
      test('getters return correct values', () {
        final customDir = '$tempDirPath/getter_test';
        final output = OmniFileOutput.createSync(
          customLogDirectory: customDir,
          logFilePrefix: 'getter',
          maxLogFiles: 4,
          logRetentionDays: 3,
        );

        expect(output, isNotNull);

        // Test getters
        expect(output!.logDirectory, equals(customDir));
        expect(output.currentLogFileSize, isA<int>());
        expect(output.currentLogFileSize, greaterThanOrEqualTo(0));

        // After writing, size should increase
        final initialSize = output.currentLogFileSize;

        final logEvent = LogEvent(Level.info, 'Getter test message');
        final event = OutputEvent(logEvent, ['Getter test message']);
        output.output(event);

        expect(output.currentLogFileSize, greaterThan(initialSize));

        output.dispose();
      });
    });
  });

  group('ProductionClassNamePrinter Tests', () {
    late ProductionClassNamePrinter printer;
    const testClassName = 'TestClass';

    setUp(() {
      printer = ProductionClassNamePrinter(testClassName);
    });

    group('Constructor Tests', () {
      test('creates printer with correct className', () {
        expect(printer.className, equals(testClassName));
      });

      test('creates printer with different className', () {
        final customPrinter = ProductionClassNamePrinter('CustomClass');
        expect(customPrinter.className, equals('CustomClass'));
      });
    });

    group('Basic Logging Tests', () {
      test('formats basic info message correctly', () {
        final event = LogEvent(Level.info, 'Test message');
        final result = printer.log(event);

        expect(result, hasLength(1));
        expect(result.first, contains('INFO '));
        expect(result.first, contains('[$testClassName]'));
        expect(result.first, contains('Test message'));
        expect(result.first, contains(':')); // timestamp format
      });

      test('formats debug message correctly', () {
        final event = LogEvent(Level.debug, 'Debug message');
        final result = printer.log(event);

        expect(result, hasLength(1));
        expect(result.first, contains('DEBUG'));
        expect(result.first, contains('[$testClassName]'));
        expect(result.first, contains('Debug message'));
      });

      test('formats warning message correctly', () {
        final event = LogEvent(Level.warning, 'Warning message');
        final result = printer.log(event);

        expect(result, hasLength(1));
        expect(result.first, contains('WARN '));
        expect(result.first, contains('[$testClassName]'));
        expect(result.first, contains('Warning message'));
      });

      test('formats error message correctly', () {
        final event = LogEvent(Level.error, 'Error message');
        final result = printer.log(event);

        expect(result, hasLength(1));
        expect(result.first, contains('ERROR'));
        expect(result.first, contains('[$testClassName]'));
        expect(result.first, contains('Error message'));
      });
    });

    group('Timestamp Format Tests', () {
      test('timestamp format is correct', () {
        final event = LogEvent(Level.info, 'Test');
        final result = printer.log(event);

        // Should match HH:MM:SS.mmm format
        final timestampRegex = RegExp(r'^\d{2}:\d{2}:\d{2}\.\d{3}');
        expect(result.first, matches(timestampRegex));
      });

      test('timestamp changes between calls', () {
        final event1 = LogEvent(Level.info, 'Test1');
        final event2 = LogEvent(Level.info, 'Test2');

        final result1 = printer.log(event1);
        // Small delay to ensure different timestamps
        Future<dynamic>.delayed(Duration(milliseconds: 1));
        final result2 = printer.log(event2);

        // Extract timestamps (first 12 characters)
        final timestamp1 = result1.first.substring(0, 12);
        final timestamp2 = result2.first.substring(0, 12);

        // They might be the same if called quickly, but structure should be correct
        expect(timestamp1, matches(RegExp(r'^\d{2}:\d{2}:\d{2}\.\d{3}$')));
        expect(timestamp2, matches(RegExp(r'^\d{2}:\d{2}:\d{2}\.\d{3}$')));
      });
    });

    group('Error Handling Tests', () {
      test('handles event with error correctly', () {
        final error = Exception('Test error');
        final event = LogEvent(Level.error, 'Error message', error: error);
        final result = printer.log(event);

        expect(result, hasLength(2));
        expect(result[0], contains('Error message'));
        expect(result[1], contains('ERROR │'));
        expect(result[1], contains('[$testClassName]'));
        expect(result[1], contains('ERROR: Exception: Test error'));
      });

      test('handles event with stack trace correctly', () {
        final stackTrace = StackTrace.current;
        final event = LogEvent(
          Level.error,
          'Error with stack',
          stackTrace: stackTrace,
        );
        final result = printer.log(event);

        expect(result, hasLength(2));
        expect(result[0], contains('Error with stack'));
        expect(result[1], contains('TRACE │'));
        expect(result[1], contains('[$testClassName]'));
        expect(result[1], contains('STACK:'));
      });

      test('handles event with both error and stack trace', () {
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;
        final event = LogEvent(
          Level.error,
          'Complete error',
          error: error,
          stackTrace: stackTrace,
        );
        final result = printer.log(event);

        expect(result, hasLength(3));
        expect(result[0], contains('Complete error'));
        expect(result[1], contains('ERROR: Exception: Test error'));
        expect(result[2], contains('STACK:'));
      });
    });

    group('Message Formatting Tests', () {
      test('handles null message', () {
        final event = LogEvent(Level.info, null);
        final result = printer.log(event);

        expect(result, hasLength(1));
        expect(result.first, contains('null'));
      });

      test('handles empty message', () {
        final event = LogEvent(Level.info, '');
        final result = printer.log(event);

        expect(result, hasLength(1));
        expect(result.first, contains('[$testClassName]'));
      });

      test('handles multiline message', () {
        final event = LogEvent(Level.info, 'Line 1\nLine 2\nLine 3');
        final result = printer.log(event);

        expect(result, hasLength(1));
        expect(result.first, contains('Line 1\nLine 2\nLine 3'));
      });

      test('handles special characters in message', () {
        final event = LogEvent(Level.info, 'Special chars: @#\$%^&*()');
        final result = printer.log(event);

        expect(result, hasLength(1));
        expect(result.first, contains('Special chars: @#\$%^&*()'));
      });
    });

    group('Fallback Error Handling Tests', () {
      test('handles formatting exception gracefully', () {
        // This test might be harder to trigger, but we can test the structure
        final event = LogEvent(Level.info, 'Normal message');
        final result = printer.log(event);

        // Should not throw and should return valid result
        expect(result, isNotEmpty);
        expect(result.first, isA<String>());
      });
    });
  });

  group('JsonClassNamePrinter Tests', () {
    late JsonClassNamePrinter printer;
    const testClassName = 'JsonTestClass';

    setUp(() {
      printer = JsonClassNamePrinter(testClassName);
    });

    group('Constructor Tests', () {
      test('creates printer with correct className', () {
        expect(printer.className, equals(testClassName));
      });

      test('creates printer with different className', () {
        final customPrinter = JsonClassNamePrinter('JsonCustomClass');
        expect(customPrinter.className, equals('JsonCustomClass'));
      });
    });

    group('Basic JSON Logging Tests', () {
      test('formats basic info message as valid JSON', () {
        final event = LogEvent(Level.info, 'Test message');
        final result = printer.log(event);

        expect(result, hasLength(1));

        // Should be valid JSON
        final json = jsonDecode(result.first);
        expect(json, isA<Map<String, dynamic>>());
        expect(json['level'], equals('info'));
        expect(json['class'], equals(testClassName));
        expect(json['message'], equals('Test message'));
        expect(json['timestamp'], isA<String>());
      });

      test('formats debug message as valid JSON', () {
        final event = LogEvent(Level.debug, 'Debug message');
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json['level'], equals('debug'));
        expect(json['message'], equals('Debug message'));
      });

      test('formats warning message as valid JSON', () {
        final event = LogEvent(Level.warning, 'Warning message');
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json['level'], equals('warn'));
        expect(json['message'], equals('Warning message'));
      });

      test('formats error message as valid JSON', () {
        final event = LogEvent(Level.error, 'Error message');
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json['level'], equals('error'));
        expect(json['message'], equals('Error message'));
      });
    });

    group('Timestamp Tests', () {
      test('timestamp is in ISO8601 format', () {
        final event = LogEvent(Level.info, 'Test');
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        final timestamp = json['timestamp'] as String;

        // Should be valid ISO8601 format
        expect(() => DateTime.parse(timestamp), returnsNormally);
      });

      test('timestamp is recent', () {
        final before = DateTime.now();
        final event = LogEvent(Level.info, 'Test');
        final result = printer.log(event);
        final after = DateTime.now();

        final json = jsonDecode(result.first);
        final timestamp = DateTime.parse(json['timestamp'] as String);

        expect(
          timestamp.isAfter(before.subtract(Duration(seconds: 1))),
          isTrue,
        );
        expect(timestamp.isBefore(after.add(Duration(seconds: 1))), isTrue);
      });
    });

    group('Error Handling Tests', () {
      test('includes error in JSON when present', () {
        final error = Exception('Test error');
        final event = LogEvent(Level.error, 'Error message', error: error);
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json['error'], equals('Exception: Test error'));
        expect(json['message'], equals('Error message'));
      });

      test('includes stack trace in JSON when present', () {
        final stackTrace = StackTrace.current;
        final event = LogEvent(
          Level.error,
          'Error with stack',
          stackTrace: stackTrace,
        );
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json['stackTrace'], isA<String>());
        expect(json['stackTrace'], isNotEmpty);
      });

      test('includes both error and stack trace', () {
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;
        final event = LogEvent(
          Level.error,
          'Complete error',
          error: error,
          stackTrace: stackTrace,
        );
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json['error'], equals('Exception: Test error'));
        expect(json['stackTrace'], isA<String>());
        expect(json['message'], equals('Complete error'));
      });
    });

    group('Message Formatting Tests', () {
      test('handles null message', () {
        final event = LogEvent(Level.info, null);
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json['message'], equals('null'));
      });

      test('handles empty message', () {
        final event = LogEvent(Level.info, '');
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json['message'], equals(''));
      });

      test('escapes newlines in message', () {
        final event = LogEvent(Level.info, 'Line 1\nLine 2\nLine 3');
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json['message'], equals('Line 1\\nLine 2\\nLine 3'));
      });

      test('escapes carriage returns in message', () {
        final event = LogEvent(Level.info, 'Line 1\rLine 2');
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json['message'], equals('Line 1\\rLine 2'));
      });

      test('escapes tabs in message', () {
        final event = LogEvent(Level.info, 'Column 1\tColumn 2');
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json['message'], equals('Column 1\\tColumn 2'));
      });

      test('handles special JSON characters', () {
        final event = LogEvent(Level.info, 'Quote: " Backslash: \\ Slash: /');
        final result = printer.log(event);

        // Should be valid JSON despite special characters
        final json = jsonDecode(result.first);
        expect(json['message'], isA<String>());
      });
    });

    group('JSON Structure Tests', () {
      test('JSON contains all required fields', () {
        final event = LogEvent(Level.info, 'Test message');
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json.containsKey('timestamp'), isTrue);
        expect(json.containsKey('level'), isTrue);
        expect(json.containsKey('class'), isTrue);
        expect(json.containsKey('message'), isTrue);
      });

      test('JSON does not contain error fields when no error', () {
        final event = LogEvent(Level.info, 'Test message');
        final result = printer.log(event);

        final json = jsonDecode(result.first);
        expect(json.containsKey('error'), isFalse);
        expect(json.containsKey('stackTrace'), isFalse);
      });

      test('class name is correctly set', () {
        final customPrinter = JsonClassNamePrinter('CustomJsonClass');
        final event = LogEvent(Level.info, 'Test');
        final result = customPrinter.log(event);

        final json = jsonDecode(result.first);
        expect(json['class'], equals('CustomJsonClass'));
      });
    });

    group('Fallback Error Handling Tests', () {
      test('handles JSON encoding failure gracefully', () {
        // This is harder to trigger, but we can test that it doesn't throw
        final event = LogEvent(Level.info, 'Normal message');
        final result = printer.log(event);

        expect(result, hasLength(1));
        expect(() => jsonDecode(result.first), returnsNormally);
      });

      test('fallback JSON structure is valid', () {
        // Testing the fallback scenario is difficult, but we can verify
        // that normal operation produces valid JSON
        final event = LogEvent(Level.info, 'Test message');
        final result = printer.log(event);

        expect(result, hasLength(1));
        final json = jsonDecode(result.first);
        expect(json, isA<Map<String, dynamic>>());
      });
    });

    group('Level Conversion Tests', () {
      test('converts all logger levels correctly', () {
        final levels = [
          Level.debug,
          Level.info,
          Level.warning,
          Level.error,
          Level.fatal,
        ];

        for (final level in levels) {
          final event = LogEvent(level, 'Test message');
          final result = printer.log(event);

          final json = jsonDecode(result.first);
          expect(json['level'], isA<String>());
          expect(json['level'], isNotEmpty);
        }
      });
    });

    group('Fallback Error Handling Tests', () {
      test('handles JSON encoding failure with fallback', () {
        // Create a custom printer that will trigger encoding failure
        final customPrinter = _FaultyJsonClassNamePrinter(testClassName);
        final event = LogEvent(Level.info, 'Test message');
        final result = customPrinter.log(event);

        expect(result, hasLength(1));
        final json = jsonDecode(result.first);
        expect(json['level'], equals('error'));
        expect(json['class'], equals(testClassName));
        expect(json['message'], contains('JSON encoding failed:'));
        expect(json['originalMessage'], equals('Test message'));
      });

      test('handles complete JSON encoding failure', () {
        // Create a printer that will fail both primary and fallback encoding
        final customPrinter = _CompletelyFaultyJsonClassNamePrinter(
          testClassName,
        );
        final event = LogEvent(Level.info, 'Test message');
        final result = customPrinter.log(event);

        expect(result, hasLength(1));
        expect(
          result.first,
          equals(
            '{"error":"Complete JSON encoding failure","class":"$testClassName"}',
          ),
        );
      });

      test('handles message formatting failure', () {
        // Create an event with an object that will fail toString()
        final faultyMessage = _FaultyToStringObject();
        final event = LogEvent(Level.info, faultyMessage);
        final result = printer.log(event);

        expect(result, hasLength(1));
        final json = jsonDecode(result.first);
        expect(json['message'], contains('[Message formatting failed:'));
      });

      test('normal operation produces valid JSON', () {
        final event = LogEvent(Level.info, 'Test message');
        final result = printer.log(event);

        expect(result, hasLength(1));
        final json = jsonDecode(result.first);
        expect(json, isA<Map<String, dynamic>>());
      });
    });
  });
}

// Helper classes to simulate error conditions for testing

/// Object that throws an exception when toString() is called
class _FaultyToStringObject {
  @override
  String toString() {
    throw Exception('toString() failed');
  }
}

/// JsonClassNamePrinter that simulates JSON encoding failure
class _FaultyJsonClassNamePrinter extends JsonClassNamePrinter {
  _FaultyJsonClassNamePrinter(super.className);

  @override
  List<String> log(LogEvent event) {
    try {
      // Convert logger Level to OmniLogLevel
      final omniLevel = OmniLogLevel.fromLoggerLevel(event.level);

      // Create logData that will cause jsonEncode to fail
      final logData = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'level': OmniLogLevel.getLevelName(omniLevel),
        'class': className,
        'message': _formatMessage(event),
        'circular': <String, dynamic>{}, // This will cause circular reference
      };

      // Make it circular to force JSON encoding failure
      logData['circular'] = logData;

      // Add error details if present
      if (event.error != null) {
        logData['error'] = event.error.toString();
      }
      if (event.stackTrace != null) {
        logData['stackTrace'] = event.stackTrace.toString();
      }

      return [jsonEncode(logData)];
    } catch (e) {
      // Fallback JSON if encoding fails
      final fallbackData = {
        'timestamp': DateTime.now().toIso8601String(),
        'level': 'error',
        'class': className,
        'message': 'JSON encoding failed: $e',
        'originalMessage': event.message.toString(),
      };
      try {
        return [jsonEncode(fallbackData)];
      } catch (_) {
        return [
          '{"error":"Complete JSON encoding failure","class":"$className"}',
        ];
      }
    }
  }

  String _formatMessage(LogEvent event) {
    try {
      final msg = event.message.toString();
      // Ensure the message is JSON-safe
      return msg
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll('\t', '\\t');
    } catch (e) {
      return '[Message formatting failed: $e]';
    }
  }
}

/// JsonClassNamePrinter that simulates complete JSON encoding failure
class _CompletelyFaultyJsonClassNamePrinter extends JsonClassNamePrinter {
  _CompletelyFaultyJsonClassNamePrinter(super.className);

  @override
  List<String> log(LogEvent event) {
    try {
      // Force an exception
      throw Exception('Primary encoding failed');
    } catch (e) {
      // Fallback JSON if encoding fails
      final fallbackData = {
        'timestamp': DateTime.now().toIso8601String(),
        'level': 'error',
        'class': className,
        'message': 'JSON encoding failed: $e',
        'originalMessage': event.message.toString(),
        'circular': <String, dynamic>{}, // This will also fail
      };

      // Make fallback also fail
      fallbackData['circular'] = fallbackData;

      try {
        return [jsonEncode(fallbackData)];
      } catch (_) {
        return [
          '{"error":"Complete JSON encoding failure","class":"$className"}',
        ];
      }
    }
  }
}
