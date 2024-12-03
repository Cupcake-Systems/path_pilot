import 'dart:developer' as dev;
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class Logger {
  final File logFile;
  final Map<String, _LogMessageTracker> _messageTracker = {};
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  Logger(String filePath) : logFile = File(filePath);

  Future<void> log(LogLevel level, String message) async {
    final now = DateTime.now();
    final tracker = _messageTracker.putIfAbsent(
      message,
      () => _LogMessageTracker(now),
    );

    if (tracker.shouldLog(now)) {
      tracker.incrementCount();
      await _writeToFile(level, message, now);
    } else if (!tracker.isBlockedMessageLogged) {
      tracker.markBlockedMessageLogged();
      await _writeToFile(level, "Message suppressed: $message", now);
    }
  }

  Future<void> _writeToFile(LogLevel level, String message, DateTime time) async {
    try {

      final msg = '${_dateFormat.format(time)}: [$level] $message\n';

      if (kDebugMode) {
        dev.log(msg, level: level.level, name: 'Logger', time: time, sequenceNumber: 0);
      }

      await logFile.writeAsString(msg, mode: FileMode.append, flush: true);
    } catch (e) {
      dev.log("Failed to write to log file: $e");
    }
  }

  Future<void> info(String message) => log(LogLevel.info, message);

  Future<void> warning(String message) => log(LogLevel.warning, message);

  Future<void> error(String message) => log(LogLevel.error, message);

  Future<void> errorWithStackTrace(String message, Object error, StackTrace stackTrace) => this.error("$message:\n$error\n$stackTrace");

  Future<void> debug(String message) => log(LogLevel.debug, message);
}

class _LogMessageTracker {
  static const _timeLimit = Duration(milliseconds: 100);
  static const _maxCount = 10;

  DateTime lastLogTime;
  int _count;
  bool isBlockedMessageLogged;

  _LogMessageTracker(this.lastLogTime)
      : _count = 0,
        isBlockedMessageLogged = false;

  bool shouldLog(DateTime now) {
    if (now.difference(lastLogTime) > _timeLimit) {
      // Reset after suppression period
      lastLogTime = now;
      _count = 0;
      isBlockedMessageLogged = false; // Allow logging suppression notice again
    }
    return _count < _maxCount;
  }

  void incrementCount() => _count++;

  void markBlockedMessageLogged() {
    isBlockedMessageLogged = true;
  }
}

enum LogLevel {
  info("INFO", 0),
  warning("WARNING", 1),
  error("ERROR", 2),
  debug("DEBUG", 0);

  final String name;
  final int level;

  const LogLevel(this.name, this.level);

  @override
  String toString() => name;
}
