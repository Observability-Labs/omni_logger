import 'package:logger/logger.dart';
import 'package:omni_logger/omni_logger.dart';

// Enhanced Development printer with better error handling
class DevClassNamePrinter extends LogPrinter {
  final String className;

  DevClassNamePrinter(this.className);

  @override
  List<String> log(LogEvent event) {
    try {
      // Convert logger Level to OmniLogLevel
      final omniLevel = OmniLogLevel.fromLoggerLevel(event.level);

      // Use the logger level for color mapping (since PrettyPrinter expects Level)
      final color = PrettyPrinter.defaultLevelColors[event.level];
      final message = _formatMessage(event);
      final levelString = OmniLogLevel.getLevelDisplayName(omniLevel);
      final icon = OmniLogLevel.levelIcons[omniLevel] ?? '📝';

      // Short timestamp for development
      final now = DateTime.now();
      final timestamp =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';

      // Visual, easy-to-scan format for development
      final formattedMessage =
          '$timestamp $icon ${levelString.padRight(5)} │ [$className] $message';

      // Add error and stack trace if present
      final lines = <String>[formattedMessage];
      if (event.error != null) {
        lines.add('    ↳ Error: ${event.error}');
      }
      if (event.stackTrace != null) {
        final stackLines = event.stackTrace.toString().split('\n');
        for (int i = 0; i < stackLines.length && i < 5; i++) {
          // Limit stack trace lines
          if (stackLines[i].trim().isNotEmpty) {
            lines.add('    ↳ ${stackLines[i].trim()}');
          }
        }
      }

      if (color != null) {
        return lines.map((line) => color(line)).toList();
      }
      return lines;
    } catch (e) {
      // Fallback if formatting fails
      return ['[DevPrinter Error] ${event.message} (formatting failed: $e)'];
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
