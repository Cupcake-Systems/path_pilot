import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/constants.dart';
import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:path_pilot/file_browser.dart';

late final PackageInfo packageInfo;

final rand = Random();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() => Stream<LicenseEntry>.value(const LicenseEntryWithLineBreaks(<String>["path_pilot"], license)));
  await AppData.init();
  packageInfo = await PackageInfo.fromPlatform();
  await RobiPainter.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Path Pilot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: FileBrowser());
  }
}
