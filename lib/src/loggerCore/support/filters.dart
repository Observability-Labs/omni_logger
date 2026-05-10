import 'package:logger/logger.dart';
import 'package:omni_logger/omni_logger.dart';

// Updated filters using OmniLogLevel
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // Convert logger Level to OmniLogLevel
    final omniLevel = OmniLogLevel.fromLoggerLevel(event.level);

    // In production, skip debug and trace, but allow info, warn, error, fatal
    return omniLevel != OmniLogLevel.debug && omniLevel != OmniLogLevel.trace;
  }
}

class CriticalOnlyFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // Convert logger Level to OmniLogLevel
    final omniLevel = OmniLogLevel.fromLoggerLevel(event.level);

    // Only error and fatal messages
    return omniLevel == OmniLogLevel.error || omniLevel == OmniLogLevel.fatal;
  }
}

// Enhanced utility filters
class ErrorWarnFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // Convert logger Level to OmniLogLevel
    final omniLevel = OmniLogLevel.fromLoggerLevel(event.level);

    return omniLevel == OmniLogLevel.error || omniLevel == OmniLogLevel.warning;
  }
}
