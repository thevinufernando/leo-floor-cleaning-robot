import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  LogEntry(this.level, this.message) : at = DateTime.now();

  final DateTime at;
  final LogLevel level;
  final String message;

  String get timeLabel {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  String toString() => '[$timeLabel] ${level.name.toUpperCase()}: $message';
}

/// Ring buffer of debug lines for UI + `flutter run` console.
class DebugLog {
  DebugLog({this.capacity = 100});

  final int capacity;
  final ListQueue<LogEntry> _entries = ListQueue<LogEntry>();
  final _controller = StreamController<LogEntry>.broadcast();

  Stream<LogEntry> get stream => _controller.stream;
  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);

  void log(LogLevel level, String message) {
    final entry = LogEntry(level, message);
    _entries.addLast(entry);
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    debugPrint(entry.toString());
    if (!_controller.isClosed) {
      _controller.add(entry);
    }
  }

  void d(String message) => log(LogLevel.debug, message);
  void i(String message) => log(LogLevel.info, message);
  void w(String message) => log(LogLevel.warn, message);
  void e(String message) => log(LogLevel.error, message);

  void clear() => _entries.clear();

  void dispose() {
    _controller.close();
  }
}
