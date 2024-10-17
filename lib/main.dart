import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:robi_line_drawer/app_storage.dart';
import 'package:robi_line_drawer/constants.dart';
import 'package:robi_line_drawer/editor/painters/robi_painter.dart';
import 'package:robi_line_drawer/file_browser.dart';
import 'package:universal_ble/universal_ble.dart';

late final PackageInfo packageInfo;

Map<String, void Function(String deviceId, bool connected)> bleConnectionChange = {};
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() => Stream<LicenseEntry>.value(const LicenseEntryWithLineBreaks(<String>["robi_line_drawer"], license)));
  await AppData.init();
  packageInfo = await PackageInfo.fromPlatform();
  await RobiPainter.init();

  UniversalBle.onConnectionChange = (deviceId, x) {
    for (final element in bleConnectionChange.values) {
      element(deviceId, x);
    }
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robi Line Drawer',
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
