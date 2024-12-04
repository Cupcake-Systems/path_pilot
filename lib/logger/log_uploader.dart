import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/backend_api/submit_log.dart';
import 'package:path_pilot/logger/logger.dart';
import 'package:path_pilot/main.dart';

class LogUploader {
  final LogFile logFile;
  static const routineDelay = Duration(minutes: 5);
  bool _runRoutine = false;

  LogUploader(this.logFile);

  void startUploadRoutine() {
    if (_runRoutine) return;
    _runRoutine = true;
    _uploadRoutine();
    logger.info("Started log upload routine");
  }

  void stopUploadRoutine() {
    _runRoutine = false;
  }

  void _uploadRoutine() async {
    while (_runRoutine) {
      if (PreservingStorage.shouldSubmitLog) {
        await uploadLog();
      }
      await Future.delayed(routineDelay);
    }
  }

  Future<bool> uploadLog() => submitLog(logFile);
}
