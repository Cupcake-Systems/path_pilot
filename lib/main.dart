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
import 'package:path_provider/path_provider.dart';

import 'logger/logger.dart';

late final PackageInfo packageInfo;
final deviceInfo = DeviceInfoPlugin();
late final Logger logger;

final rand = Random();
final snackBarKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() => Stream<LicenseEntry>.value(const LicenseEntryWithLineBreaks(<String>["path_pilot"], license)));
  await AppData.init();
  packageInfo = await PackageInfo.fromPlatform();
  await RobiPainter.init();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final localDir = await getApplicationDocumentsDirectory();
  logger = Logger("${localDir.path}/log.txt");

  logger.info("App started");

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
