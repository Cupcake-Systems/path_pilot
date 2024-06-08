import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:robi_line_drawer/editor.dart';
import 'package:robi_line_drawer/robi_path_serializer.dart';
import 'package:robi_line_drawer/robi_utils.dart';

class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key});

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser>
    with TickerProviderStateMixin {
  File? focusedFile;
  Map<String, List<MissionInstruction>> instructionTable = {};

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
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.info),
                        onPressed: () {
                          showAboutDialog(
                            context: context,
                            applicationName: "Robi Line Drawer",
                            applicationVersion: "1.0.0",
                          );
                        },
                        child: const MenuAcceleratorLabel('&About'),
                      ),
                    ],
                    child: const MenuAcceleratorLabel('&File'),
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
                    appBar: AppBar(
                      flexibleSpace: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TabBar(
                            tabAlignment: TabAlignment.start,
                            isScrollable: true,
                            tabs: instructionTable.keys
                                .map(
                                  (file) => SizedBox(
                                    width: 200,
                                    height: 54,
                                    child: ListTile(
                                      leading: const Icon(Icons.edit_document),
                                      title: Tab(
                                          text: basename(file).split(".")[0]),
                                      trailing: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            instructionTable.remove(file);
                                            if (instructionTable.isEmpty) focusedFile = null;
                                          });
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                )
                                .toList(),
                          )
                        ],
                      ),
                    ),
                    body: TabBarView(
                      children: instructionTable.values
                          .map((instructions) =>
                              Editor(instructions: instructions))
                          .toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
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
}
