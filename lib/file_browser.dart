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
import 'package:url_launcher/url_launcher_string.dart';

class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key});

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> with TickerProviderStateMixin {
  File? openedFile;

  @override
  Widget build(BuildContext context) {
    final loadedInstructions = openedFile == null ? null : getInstructionsFromFile(openedFile!);

    if (loadedInstructions == null && openedFile != null) {
      openedFile = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decode content!'),
          ),
        ),
      );
    }

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
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: const ButtonStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      onPressed: newFile,
                      label: const Text('Create'),
                    ),
                    const SizedBox(
                      height: 30,
                      child: VerticalDivider(width: 1),
                    ),
                    ElevatedButton.icon(
                      style: const ButtonStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.folder),
                      onPressed: () => openFile(context),
                      label: const Text('Open'),
                    ),
                  ],
                )
              : Editor(
                  file: openedFile!,
                  initailInstructions: loadedInstructions.toList(growable: false),
                ),
        ),
      ],
    );
  }

  Iterable<MissionInstruction>? getInstructionsFromFile(File file) {
    final data = file.readAsStringSync();
    final newInstructions = RobiPathSerializer.decode(data);
    return newInstructions;
  }

  Future<void> openTab(BuildContext context, File tab) async {
    if (openedFile != null && openedFile!.absolute.path == tab.absolute.path) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File already opened!'),
        ),
      );
      // TODO: Focus editor
      return;
    }
    setState(() => openedFile = tab);
    // TODO: Focus editor
  }

  Future<void> newFile() async {
    final result = await FilePicker.platform.saveFile(dialogTitle: "Please select an output file:", fileName: "new.robi_script.json");

    if (result == null) return;

    final file = File(result);

    if (openedFile != null && openedFile!.absolute.path == file.absolute.path) return;

    RobiPathSerializer.saveToFile(file, []);

    setState(() => openedFile = file);
  }

  Future<void> openFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["robi_script.json", ".json"],
    );
    if (result == null) return;
    final file = File(result.files.single.path!);
    if (context.mounted) openTab(context, file);
  }
}

const defaultRobiConfig = RobiConfig(0.032, 0.135, 0.075, 0.025, 0.01, "Default");
