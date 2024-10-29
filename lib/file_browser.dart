import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/constants.dart';
import 'package:robi_line_drawer/editor/editor.dart';
import 'package:robi_line_drawer/main.dart';
import 'package:robi_line_drawer/robi_api/robi_path_serializer.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:robi_line_drawer/settings/robi_config_settings.dart';
import 'package:robi_line_drawer/settings/settings.dart';
import 'package:robi_line_drawer/welcome_screen.dart';
import 'package:url_launcher/url_launcher_string.dart';

class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key});

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  File? openedFile;
  Iterable<MissionInstruction>? loadedInstructions;
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: MenuBar(
                children: [
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.add),
                        onPressed: newFile,
                        child: const MenuAcceleratorLabel('&New'),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.folder),
                        onPressed: () => openFile(context),
                        child: const MenuAcceleratorLabel('&Open'),
                      ),
                      const Divider(height: 0),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.build_circle),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const RobiConfigSettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                        child: const MenuAcceleratorLabel('&Robi Configs'),
                      ),
                      const Divider(height: 0),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.settings),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                          setState(() {});
                        },
                        child: const MenuAcceleratorLabel('&Preferences'),
                      ),
                    ],
                    child: const MenuAcceleratorLabel('&File'),
                  ),
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.bug_report),
                        onPressed: () => launchUrlString("$repoUrl/issues/new"),
                        child: const MenuAcceleratorLabel('&Report A Bug'),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.check_circle),
                        onPressed: () => launchUrlString("$repoUrl/issues?q=is%3Aissue"),
                        child: const MenuAcceleratorLabel('&Known Issues'),
                      ),
                      const Divider(height: 0),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.menu_book),
                        onPressed: () => launchUrlString("$repoUrl/wiki"),
                        child: const MenuAcceleratorLabel('&Wiki'),
                      ),
                      const Divider(height: 0),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.info),
                        onPressed: () {
                          showAboutDialog(
                            context: context,
                            applicationName: "Robi Line Drawer",
                            applicationVersion: packageInfo.version,
                            applicationLegalese: "© Copyright Finn Drünert 2024",
                            children: [
                              Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => launchUrlString(repoUrl),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Text("GitHub Repo"),
                                  ),
                                ),
                              )
                            ],
                          );
                        },
                        child: const MenuAcceleratorLabel('&About'),
                      ),
                    ],
                    child: const MenuAcceleratorLabel("&Help"),
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: openedFile == null || loadedInstructions == null
              ? WelcomeScreen(
                  newFilePressed: newFile,
                  openFilePressed: () => openFile(context),
                  errorMessage: errorMessage,
                )
              : Editor(
                  key: ObjectKey(openedFile),
                  file: openedFile!,
                  initialInstructions: loadedInstructions!.toList(),
                ),
        ),
      ],
    );
  }

  Future<Iterable<MissionInstruction>?> getInstructionsFromFile(File file) async {
    final data = await file.readAsString();
    final newInstructions = RobiPathSerializer.decode(data);
    return newInstructions;
  }

  Future<void> newFile() async {
    final result = await FilePicker.platform.saveFile(dialogTitle: "Please select an output file:", fileName: "new.robi_script.json");

    if (result == null) return;

    setState(() {
      openedFile =  File(result);
      loadedInstructions = [];
      errorMessage = null;
    });
  }

  Future<void> openFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["robi_script.json", ".json"],
    );
    if (result == null) return;

    final file = File(result.files.single.path!);
    await tryLoadingInstructions(file);
  }

  Future<void> tryLoadingInstructions(File file) async {
    final instructions = await getInstructionsFromFile(file);

    setState(() {
      if (instructions == null) {
        errorMessage = "Failed to decode content!";
        openedFile = null;
      } else {
        errorMessage = null;
        openedFile = file;
      }
      loadedInstructions = instructions;
    });
  }
}

const defaultRobiConfig = RobiConfig(0.032, 0.135, 0.075, 0.025, 0.01, "Default");
