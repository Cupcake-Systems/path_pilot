import 'package:http/http.dart' as http;
import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/backend_api/urls.dart';
import 'package:path_pilot/helper/json_parser.dart';
import 'package:path_pilot/logger/logger.dart';

import '../main.dart';

Future<bool> submitLog(LogFile logFile) async {
  try {
    final msgs = await logFile.read();

    final lastSubmittedLogTime = PreservingStorage.lastSubmittedLogTime;
    final msgsSinceLastSubmit = lastSubmittedLogTime == null ? msgs : LogFile.since(msgs, lastSubmittedLogTime);

    if (msgsSinceLastSubmit.isEmpty) {
      logger.info("No new logs to submit");
      return true;
    }

    final jsonMsgs = msgsSinceLastSubmit.map((e) => e.toJson()).toList();
    final encoded = await JsonParser.stringifyIsolated(jsonMsgs);

    final response = await http.post(
      Uri.parse(submitLogUrl),
      body: encoded,
      headers: {
        "Content-Type": "application/json",
        ...identificationHeader,
      },
    );

    if (response.statusCode != 200) {
      logger.error("Endpoint rejected log: ${response.body}");
      return false;
    }

    PreservingStorage.lastSubmittedLogTime = msgsSinceLastSubmit.last.time;

    logger.info("${msgsSinceLastSubmit.length} new log entries submitted successfully");

    return true;
  } catch (e, s) {
    logger.errorWithStackTrace("Failed to submit log", e, s);
    return false;
  }
}
