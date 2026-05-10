import 'dart:io';

/// Data class for log file information
class LogFileInfo {
  final File? file;
  final String currentDate;
  final int currentSize; // Always in bytes
  final String? error;

  LogFileInfo({
    required this.file,
    required this.currentDate,
    required this.currentSize,
    this.error,
  });
}
