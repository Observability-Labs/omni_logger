import 'package:logger/logger.dart';
import 'package:omni_logger/omni_logger.dart';

// Enhanced Production printer with precise timestamps
class ProductionClassNamePrinter extends LogPrinter {
  final String className;

  ProductionClassNamePrinter(this.className);

  @override
  List<String> log(LogEvent event) {
    try {
      // Convert logger Level to OmniLogLevel
      final omniLevel = OmniLogLevel.fromLoggerLevel(event.level);

      final message = _formatMessage(event);
      final levelTag = OmniLogLevel.levelTags[omniLevel] ?? 'LOG  ';

      // Precise timestamp for production logs
      final now = DateTime.now();
      final timestamp =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}.'
          '${now.millisecond.toString().padLeft(3, '0')}';

      // Clean, grep-friendly format for production
      final formattedMessage =
          '$timestamp ${levelTag.padRight(5)} │ [$className] $message';

      final lines = <String>[formattedMessage];

      // Add error and stack trace for production (condensed format)
      if (event.error != null) {
        lines.add('$timestamp ERROR │ [$className] ERROR: ${event.error}');
      }
      if (event.stackTrace != null) {
        // Only show first line of stack trace in production
        final firstStackLine = event.stackTrace
            .toString()
            .split('\n')
            .first
            .trim();
        if (firstStackLine.isNotEmpty) {
          lines.add('$timestamp TRACE │ [$className] STACK: $firstStackLine');
        }
      }

      return lines;
    } catch (e) {
      // Fallback if formatting fails
      return [
        '[ProductionPrinter Error] ${event.message} (formatting failed: $e)',
      ];
    }
  }

  String _formatMessage(LogEvent event) {
    try {
      return event.message.toString();
    } catch (e) {
      return '[Message formatting failed: $e]';
    }
  }
}
