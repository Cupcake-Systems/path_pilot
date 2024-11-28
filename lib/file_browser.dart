import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/constants.dart';
import 'package:path_pilot/editor/editor.dart';
import 'package:path_pilot/editor/obstacles/obstacle_creator_widget.dart';
import 'package:path_pilot/helper/file_manager.dart';
import 'package:path_pilot/helper/save_system.dart';
import 'package:path_pilot/main.dart';
import 'package:path_pilot/robi_api/exporter/exporter.dart';
import 'package:path_pilot/robi_api/ir_read_api.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';
import 'package:path_pilot/settings/robi_config_settings.dart';
import 'package:path_pilot/settings/settings.dart';
import 'package:path_pilot/welcome_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'editor/ir_visualizer/ir_visualizer.dart';

class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key});

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> with WidgetsBindingObserver {
  RobiConfig selectedRobiConfig = defaultRobiConfig;
  ViewMode viewMode = ViewMode.instructions;
  SubViewMode subViewMode = Platform.isAndroid ? SubViewMode.editor : SubViewMode.split;
  bool showObstacles = true;
  final isSavedNotifier = IsSavedNotifier();

  // Instructions Editor
  String? openedFile;
  String? errorMessage;
  SaveData loadedData = SaveData.empty;
  SimulationResult? simulationResult;

  // IR Readings analysis
  IrReadResult? irReadResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SettingsStorage.startAutoSaveTimer(
      () {
        if (!isSavedNotifier.isSaved) {
          saveFile(false);
        }
      },
    );
  }

  @override
  void dispose() {
    isSavedNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    SettingsStorage.stopAutoSaveTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isSavedNotifier.isSaved && SettingsStorage.saveTriggers.contains(state)) {
      saveFile(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(viewMode == ViewMode.instructions ? "Instructions" : "IR Readings"),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        actions: [
          DropdownButton<SubViewMode>(
            value: subViewMode,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            borderRadius: BorderRadius.circular(8),
            items: [
              const DropdownMenuItem(
                value: SubViewMode.visualizer,
                child: Text("Visualizer"),
              ),
              const DropdownMenuItem(
                value: SubViewMode.editor,
                child: Text("Editor"),
              ),
              const DropdownMenuItem(
                value: SubViewMode.split,
                child: Text("Split"),
              ),
            ],
            onChanged: (value) => setState(() => subViewMode = value ?? subViewMode),
          ),
          const SizedBox(width: 10),
          ListenableBuilder(
              listenable: isSavedNotifier,
              builder: (context, child) {
                String saveText = "";

                if (isSavedNotifier.lastSave != null) {
                  saveText = "Last saved: ${DateFormat('kk:mm').format(isSavedNotifier.lastSave!)}\n";
                }
                final isSaving = isSavedNotifier.isSaving;
                return PopupMenuButton(
                  itemBuilder: (context) => <PopupMenuEntry>[
                    if (viewMode == ViewMode.instructions) ...[
                      PopupMenuItem(
                        child: ListTile(
                          title: const Text("New"),
                          onTap: newFile,
                          leading: const Icon(Icons.add),
                        ),
                      ),
                      PopupMenuItem(
                        child: ListTile(
                          title: const Text("Open"),
                          onTap: openFile,
                          leading: const Icon(Icons.folder_open),
                        ),
                      ),
                      if (openedFile != null) ...[
                        const PopupMenuDivider(height: 1),
                        PopupMenuItem(
                          enabled: !isSaving,
                          onTap: saveFile,
                          child: ListTile(
                            title: const Text("Save"),
                            subtitle: Text("$saveText$openedFile"),
                            leading: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(),
                                  )
                                : const Icon(Icons.save),
                          ),
                        ),
                        PopupMenuItem(
                          child: ListTile(
                            title: const Text("Save As"),
                            onTap: saveAsFile,
                            leading: const Icon(Icons.save_as),
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        PopupMenuItem(
                          child: ListTile(
                            title: const Text("Export"),
                            onTap: () {
                              if (simulationResult == null || simulationResult!.instructionResults.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text("Nothing to export"),
                                  duration: Duration(seconds: 2),
                                ));
                                return;
                              }
                              Exporter.exportToFile(
                                selectedRobiConfig,
                                simulationResult!.instructionResults,
                                context,
                              );
                            },
                            leading: const Icon(Icons.file_upload_outlined),
                          ),
                        ),
                      ],
                    ] else if (viewMode == ViewMode.irReadings) ...[
                      PopupMenuItem(
                        child: ListTile(
                          title: const Text("Import IR Reading"),
                          onTap: importIrReading,
                          leading: const Icon(Icons.file_download_outlined),
                        ),
                      ),
                    ],
                  ],
                  onSelected: (value) {
                    setState(() {});
                  },
                );
              })
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  DrawerHeader(
                    padding: EdgeInsets.zero,
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(width: 1, color: Colors.grey)),
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white, // Fully visible
                            Colors.white, // Keep visible for a longer area
                            Colors.transparent, // Fades out
                          ],
                          stops: [0.0, 0.7, 1.0], // Control the fade areas
                        ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
                      },
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(
                        "assets/repo_banner.webp",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Mode",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  RadioListTile(
                    value: ViewMode.instructions,
                    groupValue: viewMode,
                    onChanged: (value) => setState(() => viewMode = ViewMode.instructions),
                    title: const Text("Instructions"),
                  ),
                  RadioListTile(
                    value: ViewMode.irReadings,
                    groupValue: viewMode,
                    onChanged: (value) => setState(() => viewMode = ViewMode.irReadings),
                    title: const Text("IR Readings"),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.square_rounded),
                    title: const Text("Obstacles"),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ObstacleCreator(
                            obstacles: loadedData.obstacles,
                            onObstaclesChange: (obstacles) {
                              setState(() {
                                loadedData = loadedData.copyWith(obstacles: obstacles);
                              });
                              isSavedNotifier.isSaved = false;
                            },
                          ),
                        ),
                      );
                    },
                    trailing: Checkbox(
                      value: showObstacles,
                      onChanged: (value) => setState(() => showObstacles = value == true),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.build_circle),
                    title: const Text("Robi Configs"),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => RobiConfigSettingsPage(
                            onConfigSelected: (selectedConfig) => setState(() => selectedRobiConfig = selectedConfig),
                            selectedConfig: selectedRobiConfig,
                          ),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bug_report),
                    onTap: () => launchUrlString("$repoUrl/issues/new"),
                    title: const Text('Report A Bug'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.menu_book),
                    onTap: () => launchUrlString("$repoUrl/wiki"),
                    title: const Text('Wiki'),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: "Path Pilot",
                  applicationVersion: packageInfo.version,
                  applicationLegalese: "© Copyright Finn Drünert 2024",
                  children: [
                    const SizedBox(height: 25),
                    ElevatedButton.icon(
                      onPressed: () => launchUrlString(repoUrl),
                      label: const Text("GitHub Repo"),
                      icon: const Icon(Icons.open_in_new),
                    )
                  ],
                );
              },
              title: const Text('About'),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Preferences"),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsPage(),
                  ),
                );
                setState(() {});
              },
            ),
          ],
        ),
      ),
      body: getView(),
    );
  }

  Widget getView() {
    switch (viewMode) {
      case ViewMode.instructions:
        if (openedFile == null) {
          return WelcomeScreen(
            newFilePressed: newFile,
            openFilePressed: openFile,
            errorMessage: errorMessage,
          );
        }
        return Editor(
          key: ObjectKey(openedFile),
          subViewMode: subViewMode,
          initialInstructions: loadedData.instructions,
          selectedRobiConfig: selectedRobiConfig,
          onInstructionsChanged: (newInstructions, newSimulationResult) {
            loadedData = loadedData.copyWith(instructions: newInstructions);
            simulationResult = newSimulationResult;
            isSavedNotifier.isSaved = false;
          },
          firstSimulationResult: (result) {
            simulationResult = result;
          },
          obstacles: showObstacles ? loadedData.obstacles : null,
        );
      case ViewMode.irReadings:
        if (irReadResult == null) {
          return Center(
            child: ElevatedButton.icon(
              onPressed: importIrReading,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text("Import IR Reading"),
            ),
          );
        }

        return IrVisualizerWidget(
          robiConfig: selectedRobiConfig,
          irReadResult: irReadResult!,
          subViewMode: subViewMode,
          obstacles: showObstacles ? loadedData.obstacles : null,
        );
    }
  }

  Future<void> importIrReading() async {
    final result = await pickSingleFile(
      context: context,
      dialogTitle: "Select IR Reading File",
      allowedExtensions: ["bin"],
    );

    if (result == null || !mounted) return;

    final loaded = await IrReadResult.fromFile(result, context);

    if (loaded == null) return;

    setState(() {
      irReadResult = loaded;
    });
  }

  Future<File?> saveFile([bool showStatusMessage = true]) async {
    if (openedFile == null) return null;

    isSavedNotifier.isSaving = true;
    final res = await loadedData.saveToFileWithStatusMessage(openedFile!, showStatusMessage ? context : null);
    if (res != null) {
      isSavedNotifier.isSaved = true;
    }
    return res;
  }

  Future<void> saveAsFile() async {
    final result = await pickFileAndWriteWithStatusMessage(
      context: context,
      bytes: loadedData.toBytes(),
      extension: ".robi_script.json",
    );

    if (result == null) return;

    isSavedNotifier.isSaved = true;

    setState(() {
      openedFile = result.absolute.path;
      errorMessage = null;
    });
  }

  Future<void> newFile() async {
    final result = await pickFileAndWriteWithStatusMessage(
      bytes: Uint8List(0),
      context: context,
      extension: ".robi_script.json",
    );

    if (result == null) return;

    isSavedNotifier.isSaved = true;

    setState(() {
      openedFile = result.absolute.path;
      loadedData = SaveData.empty;
      errorMessage = null;
    });
  }

  Future<void> openFile() async {
    final result = await pickSingleFile(
      context: context,
      dialogTitle: "Select Robi Script File",
      allowedExtensions: ["json", "robi_script.json"],
    );
    if (result == null) return;

    if (await tryLoadingSaveData(result)) {
      isSavedNotifier.isSaved = true;
    }
  }

  Future<bool> tryLoadingSaveData(String file) async {
    final instructions = await SaveData.fromFileWithStatusMessage(file, context);

    setState(() {
      if (instructions == null) {
        errorMessage = "Failed to decode content!";
        openedFile = null;
      } else {
        errorMessage = null;
        openedFile = file;
        loadedData = instructions;
      }
    });

    return instructions != null;
  }
}

const defaultRobiConfig = RobiConfig(wheelRadius: 0.032, trackWidth: 0.135, distanceWheelIr: 0.075, wheelWidth: 0.025, irDistance: 0.01, name: "Default");

Future<bool> getExternalStoragePermission() async {
  if (!Platform.isAndroid) return true;

  final info = await deviceInfo.androidInfo;
  PermissionStatus status;

  if (info.version.sdkInt < 30) {
    status = await Permission.storage.status;

    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
  } else {
    status = await Permission.manageExternalStorage.status;

    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
  }

  return status.isGranted;
}

enum ViewMode {
  instructions,
  irReadings,
}

enum SubViewMode {
  visualizer,
  editor,
  split,
}

class IsSavedNotifier extends ChangeNotifier {
  bool _isSaved = false, _isSaving = false;
  DateTime? _lastSave;

  DateTime? get lastSave => _lastSave;

  bool get isSaved => _isSaved;

  bool get isSaving => _isSaving;

  set isSaving(bool saving) {
    _isSaving = saving;
    notifyListeners();
  }

  set isSaved(bool saved) {
    _isSaved = saved;
    if (saved) {
      _lastSave = DateTime.now();
      _isSaving = false;
    }
    notifyListeners();
  }
}
