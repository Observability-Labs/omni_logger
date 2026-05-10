import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:omni_logger/omni_logger.dart';

// Enhanced JSON printer with better error handling
class JsonClassNamePrinter extends LogPrinter {
  final String className;

  JsonClassNamePrinter(this.className);

  @override
  List<String> log(LogEvent event) {
    try {
      // Convert logger Level to OmniLogLevel
      final omniLevel = OmniLogLevel.fromLoggerLevel(event.level);

      final logData = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'level': OmniLogLevel.getLevelName(omniLevel),
        'class': className,
        'message': _formatMessage(event),
      };

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
