import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/constants.dart';
import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:path_pilot/file_browser.dart';
import 'package:path_pilot/logger/log_uploader.dart';
import 'package:path_provider/path_provider.dart';

import 'logger/logger.dart';

late final PackageInfo packageInfo;
final deviceInfo = DeviceInfoPlugin();

late final LogFile logFile;
late final Logger logger;

final rand = Random();
final snackBarKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  packageInfo = await PackageInfo.fromPlatform();

  final localDir = "${(await getApplicationDocumentsDirectory()).path}/path_pilot";
  if (!await Directory(localDir).exists()) {
    await Directory(localDir).create(recursive: true);
  }

  logFile = LogFile(File("$localDir/log.txt"), onOperationCompleted: (op) {});
  logger = Logger(logFile);
  logger.info("App V${packageInfo.version} started");

  LicenseRegistry.addLicense(() => Stream<LicenseEntry>.value(const LicenseEntryWithLineBreaks(<String>["path_pilot"], license)));
  await AppData.init();
  await RobiPainter.init();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final logUploader = LogUploader(logFile);
  logUploader.startUploadRoutine();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Path Pilot',
      scaffoldMessengerKey: snackBarKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const FileBrowser(),
    );
  }
}
