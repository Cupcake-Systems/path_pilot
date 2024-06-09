import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:robi_line_drawer/editor.dart';
import 'package:robi_line_drawer/robi_config.dart';
import 'package:robi_line_drawer/robi_path_serializer.dart';
import 'package:robi_line_drawer/robi_utils.dart';
import 'package:robi_line_drawer/settings/settings.dart';

import 'exporter.dart';

class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key});

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser>
    with TickerProviderStateMixin {
  File? focusedFile;
  final Map<String, List<MissionInstruction>> instructionTable = {};

  RobiConfig selectedRobiConfig = RobiConfig(0.035, 0.147, name: "Default");
  late final List<RobiConfig> robiConfigs = [selectedRobiConfig];

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
                        leadingIcon: const Icon(Icons.save),
                        onPressed: focusedFile == null
                            ? null
                            : () {
                                RobiPathSerializer.saveToFile(
                                    focusedFile!,
                                    instructionTable[
                                        focusedFile!.absolute.path]!);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Saved')),
                                );
                              },
                        child: const MenuAcceleratorLabel('&Save'),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.save_as),
                        onPressed: focusedFile == null ? null : saveAs,
                        child: const MenuAcceleratorLabel('&Save as...'),
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
                        leadingIcon: const Icon(Icons.add),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => RobiConfigurator(
                              addedConfig: (config) => setState(() {
                                    robiConfigs.add(config);
                                    selectedRobiConfig = config;
                                  }),
                              index: robiConfigs.length),
                        ),
                        child: const MenuAcceleratorLabel('&New'),
                      ),
                      const Divider(height: 0),
                      SubmenuButton(
                        menuChildren: [
                          for (int i = 0; i < robiConfigs.length; ++i)
                            RadioMenuButton(
                              trailingIcon: robiConfigs.length <= 1
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => setState(() {
                                        robiConfigs.remove(robiConfigs[i]);
                                        selectedRobiConfig = robiConfigs[0];
                                      }),
                                    ),
                              value: robiConfigs[i],
                              groupValue: selectedRobiConfig,
                              onChanged: (value) =>
                                  setState(() => selectedRobiConfig = value!),
                              child: MenuAcceleratorLabel(
                                  robiConfigs[i].name ?? '&Config ${i + 1}'),
                            )
                        ],
                        child: const MenuAcceleratorLabel('&Select'),
                      ),
                    ],
                    child: const MenuAcceleratorLabel("&Robi Config"),
                  ),
                  SubmenuButton(
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.info),
                        onPressed: () {
                          showAboutDialog(
                              context: context,
                              applicationName: "Robi Line Drawer",
                              applicationVersion: "1.0.0",
                              applicationLegalese:
                                  "© Copyright Finn Drünert 2024");
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
          child: instructionTable.isEmpty
              ? const Center()
              : DefaultTabController(
                  length: instructionTable.length,
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
                                labelPadding:
                                    const EdgeInsets.symmetric(horizontal: 5),
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
                    body: TabBarView(
                      children: instructionTable.values
                          .map(
                            (instructions) => Editor(
                              instructions: instructions,
                              robiConfig: selectedRobiConfig,
                              exportPressed: () async {
                                final path = await FilePicker.platform.saveFile(
                                  dialogTitle: "Please select an output file:",
                                  fileName: "exported.json",
                                );
                                if (path == null) return;
                                Exporter.saveToFile(
                                  File(path),
                                  selectedRobiConfig,
                                  instructions,
                                );
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  List<Widget> buildTabs() {
    return instructionTable.keys
        .map(
          (file) => SizedBox(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_document, size: 15),
                const SizedBox(width: 10),
                Text(basename(file).split(".")[0], textAlign: TextAlign.center),
                const SizedBox(width: 10),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() {
                      instructionTable.remove(file);
                      if (instructionTable.isEmpty) focusedFile = null;
                    }),
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
    final Iterable<MissionInstruction>? newInstructions;

    if (!instructionTable.containsKey(tab.absolute.path)) {
      final data = await tab.readAsString(encoding: ascii);
      newInstructions = RobiPathSerializer.decode(data);

      if (newInstructions == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to decode content!'),
            ),
          );
        }
        return;
      }

      setState(() {
        instructionTable[tab.absolute.path] = newInstructions!.toList();
        focusedFile = tab;
      });
    } else {
      setState(() => focusedFile = tab);
    }
  }

  Future<void> saveAs() async {
    final result = await FilePicker.platform.saveFile(
        dialogTitle: "Please select an output file:",
        fileName: "path.robi_script.json");

    if (result == null) return;

    final file = File(result);

    RobiPathSerializer.saveToFile(
        file, instructionTable[focusedFile!.absolute.path]!);

    setState(() => focusedFile = file);
  }

  Future<void> newFile() async {
    final result = await FilePicker.platform.saveFile(
        dialogTitle: "Please select an output file:",
        fileName: "new.robi_script.json");

    if (result == null) return;

    final file = File(result);

    instructionTable[file.absolute.path] = [];

    RobiPathSerializer.saveToFile(file, []);

    setState(() => focusedFile = file);
  }
}
