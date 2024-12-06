import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/backend_api/submit_log.dart';
import 'package:path_pilot/logger/logger.dart';
import 'package:path_pilot/main.dart';

class LogUploader {
  final LogFile logFile;
  Duration routineDelay = const Duration(minutes: 5);
  bool _runRoutine = false;

  LogUploader(this.logFile);

  void startUploadRoutine() {
    if (_runRoutine) return;
    _runRoutine = true;
    _uploadRoutine();
  }

  void stopUploadRoutine() {
    _runRoutine = false;
  }

  void _uploadRoutine() async {
    logger.info("Started log upload routine");
    while (_runRoutine) {
      if (PreservingStorage.shouldSubmitLog && SettingsStorage.sendLog) {
        logger.info("The app has logged an error, submitting log");

        final success = await uploadLog();

        if (success) {
          PreservingStorage.shouldSubmitLog = false;
        } else {
          routineDelay *= 2;
          logger.info("Failed to submit log, retrying in ${routineDelay.inMinutes} minutes");
        }
      }
      await Future.delayed(routineDelay);
    }
    logger.info("Stopped log upload routine");
  }

  Future<bool> uploadLog() => submitLog(logFile);
}
