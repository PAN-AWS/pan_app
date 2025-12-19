import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void info(String message) {
    debugPrint('[PAN] $message');
  }

  static void warn(String message) {
    debugPrint('[PAN][WARN] $message');
  }

  static void error(String message) {
    debugPrint('[PAN][ERROR] $message');
  }
}
