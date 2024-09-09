import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:robi_line_drawer/constants.dart';
import 'package:robi_line_drawer/editor/editor.dart';
import 'package:robi_line_drawer/main.dart';
import 'package:robi_line_drawer/robi_api/robi_path_serializer.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:robi_line_drawer/settings/settings.dart';
import 'package:url_launcher/url_launcher_string.dart';

class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key});

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> with TickerProviderStateMixin {
  List<Editor> openTabs = [];

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
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ["robi_script.json", ".json"],
                          );
                          if (result == null) return;
                          final file = File(result.files.single.path!);
                          if (context.mounted) openTab(context, file);
                        },
                        child: const MenuAcceleratorLabel('&Open'),
                      ),
                      const Divider(height: 0),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.settings),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
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
          child: openTabs.isEmpty
              ? Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    onPressed: newFile,
                    label: const Text('Create'),
                  ),
                )
              : DefaultTabController(
                  length: openTabs.length,
                  child: Scaffold(
                    appBar: PreferredSize(
                      preferredSize: const Size.fromHeight(32),
                      child: AppBar(
                        flexibleSpace: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              child: TabBar(
                                labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                                tabAlignment: TabAlignment.start,
                                isScrollable: true,
                                labelColor: Colors.white,
                                tabs: buildTabs(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    body: TabBarView(children: openTabs),
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> buildTabs() {
    return openTabs
        .map(
          (editor) => SizedBox(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_document, size: 15),
                const SizedBox(width: 10),
                Text(basename(editor.file.path).split(".robi_script.json")[0], textAlign: TextAlign.center),
                const SizedBox(width: 10),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() => openTabs.remove(editor));
                    },
                    iconSize: 17,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  Future<void> openTab(BuildContext context, File tab) async {
    for (int i = 0; i < openTabs.length; ++i) {
      if (openTabs[i].file.absolute.path == tab.absolute.path) {
        // TODO: Focus editor
        return;
      }
    }

    final data = await tab.readAsString();
    final newInstructions = RobiPathSerializer.decode(data);

    if (newInstructions == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to decode content!'),
        ),
      );
      return;
    }

    setState(() {
      openTabs.add(
        Editor(
          initailInstructions: newInstructions.toList(),
          file: tab,
        ),
      );
    });

    // TODO: Focus editor
  }

  Future<void> newFile() async {
    final result = await FilePicker.platform.saveFile(dialogTitle: "Please select an output file:", fileName: "new.robi_script.json");

    if (result == null) return;

    final file = File(result);

    for (final t in openTabs) {
      if (t.file.absolute.path == file.absolute.path) return;
    }

    RobiPathSerializer.saveToFile(file, []);

    setState(
      () => openTabs.add(
        Editor(
          initailInstructions: const [],
          file: file,
        ),
      ),
    );
  }
}

const defaultRobiConfig = RobiConfig(0.032, 0.147, 0.06, 0.025, 0.01, name: "Default");
