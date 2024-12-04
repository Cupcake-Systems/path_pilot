import 'dart:developer' as dev;
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_pilot/app_storage.dart';

class Logger {
  final LogFile logFile;
  final Map<String, _LogMessageTracker> _messageTracker = {};
  static final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  Logger(this.logFile);

  Future<void> log(LogLevel level, String message) async {
    final now = DateTime.now();
    final tracker = _messageTracker.putIfAbsent(
      message,
      () => _LogMessageTracker(now),
    );

    final logMessage = LogMessage(message: message, time: now, level: level);

    if (tracker.shouldLog(now)) {
      tracker.incrementCount();
      await _writeToFile(logMessage);
      if (logMessage.level.level > LogLevel.error.level) {
        PreservingStorage.shouldSubmitLog = true;
      }
    } else if (!tracker.isBlockedMessageLogged) {
      tracker.markBlockedMessageLogged();
      final suppressedMessage = LogMessage(message: "Message suppressed: $message", time: now, level: LogLevel.warning);
      await _writeToFile(suppressedMessage);
    }
  }

  Future<void> _writeToFile(LogMessage logMessage) async {
    try {
      if (kDebugMode) {
        dev.log(logMessage.message, name: 'Logger', time: logMessage.time);
      }

      logFile.add(logMessage);
    } catch (e) {
      dev.log("Failed to write to log file", error: e);
    }
  }

  Future<void> info(String message) => log(LogLevel.info, message);

  Future<void> warning(String message) => log(LogLevel.warning, message);

  Future<void> error(String message) => log(LogLevel.error, message);

  Future<void> errorWithStackTrace(String message, Object error, StackTrace stackTrace) => this.error("$message:\n$error\n$stackTrace");

  Future<void> fatal(String message) => log(LogLevel.fatal, message);

  Future<void> fatalWithStackTrace(String message, Object error, StackTrace stackTrace) => fatal("$message:\n$error\n$stackTrace");

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

class LogFile {
  final File file;
  final void Function(WriteOperation op) onOperationCompleted;

  bool _runRoutine = false;
  bool _isWriting = false;
  final _writeQueue = <WriteOperation>[];

  LogFile(this.file, {required this.onOperationCompleted}) {
    _writeRoutine();
  }

  void add(LogMessage message) => _writeQueue.add(
        WriteOperation(
          mode: FileMode.append,
          data: "${message.toCsvLine()}\n",
          flush: true,
        ),
      );

  void _writeRoutine() async {
    if (_runRoutine) return;
    _runRoutine = true;
    while (_runRoutine) {
      while (_writeQueue.isNotEmpty) {
        _isWriting = true;
        final op = _writeQueue.removeAt(0);
        await op.execute(file);
      }

      _isWriting = false;

      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> awaitWrite() async {
    while (_isWriting) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void stop() => _runRoutine = false;

  Future<String> readRaw() async {
    await awaitWrite();
    return file.readAsString();
  }

  Future<List<LogMessage>> read() async {
    await awaitWrite();
    final lines = await file.readAsLines();
    return lines.map((e) => LogMessage.tryParseFromCsvLine(e)).whereType<LogMessage>().toList();
  }

  void clear() => _writeQueue.add(
        const WriteOperation(
          mode: FileMode.write,
          data: "",
          flush: true,
        ),
      );
}

final class WriteOperation {
  final FileMode mode;
  final String data;
  final bool flush;

  const WriteOperation({required this.mode, required this.data, required this.flush});

  Future<void> execute(File file) async {
    await file.writeAsString(data, mode: mode, flush: flush);
  }
}

final class LogMessage {
  final String message;
  final DateTime time;
  final LogLevel level;

  const LogMessage({
    required this.message,
    required this.time,
    required this.level,
  });

  String get date => DateFormat('yyyy-MM-dd').format(time);

  String toCsvLine() {
    final withoutSemicolons = message.trim().replaceAll(";", "\\;");
    final escapedMessage = withoutSemicolons.replaceAll("\n", "\\n").replaceAll("\r", "");
    return "${time.toIso8601String()};$level;$escapedMessage";
  }

  Map<String, String> toJson() => {
        "message": message,
        "time": time.toIso8601String(),
        "level": level.name,
      };

  static final simSplitPattern = RegExp(r'(?<!\\);');

  factory LogMessage.fromCsvLine(String line) {
    line = line.trim();
    final parts = line.split(simSplitPattern);
    final time = DateTime.parse(parts[0]);
    final level = LogLevel.fromString(parts[1]);
    final message = parts[2].replaceAll("\\n", "\n").replaceAll("\\;", ";");

    return LogMessage(message: message, time: time, level: level);
  }

  static LogMessage? tryParseFromCsvLine(String line) {
    try {
      return LogMessage.fromCsvLine(line);
    } catch (e, s) {
      dev.log("Failed to parse log message from CSV line: $line", error: e, stackTrace: s);
      return null;
    }
  }

  String get formattedTime => Logger.dateFormat.format(time);
}

enum LogLevel {
  info("INFO", 0, Color(0xFF2196F3), Icons.info),
  warning("WARNING", 1, Color(0xFFFFC107), Icons.warning),
  error("ERROR", 2, Color(0xFFF44336), Icons.error),
  fatal("FATAL", 3, Color(0xFFB71C1C), Icons.error_outline),
  debug("DEBUG", 0, Color(0xFF7F7F7F), Icons.bug_report);

  final String name;
  final int level;
  final Color color;
  final IconData icon;

  const LogLevel(this.name, this.level, this.color, this.icon);

  @override
  String toString() => name;

  factory LogLevel.fromString(String s) {
    if (s == info.name) {
      return info;
    } else if (s == warning.name) {
      return warning;
    } else if (s == error.name) {
      return error;
    } else if (s == fatal.name) {
      return fatal;
    } else if (s == debug.name) {
      return debug;
    } else {
      throw ArgumentError("Invalid log level: $s");
    }
  }
}