import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor.dart';
import 'package:robi_line_drawer/robi_path_serializer.dart';
import 'package:robi_line_drawer/robi_utils.dart';

class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key});

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  File? focusedFile;

  List<MissionInstruction> instructions = [];

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
                          final result = await FilePicker.platform.pickFiles();
                          if (result == null) return;

                          final file = File(result.files.single.path!);
                          final data = await file.readAsString(encoding: ascii);
                          final newInstructions =
                              RobiPathSerializer.decode(data);

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
                            instructions = newInstructions.toList();
                            focusedFile = file;
                          });
                        },
                        child: const MenuAcceleratorLabel('&Open'),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.save),
                        onPressed: () {
                          if (focusedFile == null) {
                            saveAs();
                            return;
                          }
                          RobiPathSerializer.saveToFile(focusedFile!, instructions);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Saved')),
                          );
                        },
                        child: const MenuAcceleratorLabel('&Save'),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.save_as),
                        onPressed: saveAs,
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
        Expanded(child: Editor(instructions: instructions)),
      ],
    );
  }

  Future<void> saveAs() async {
    final result = await FilePicker.platform.saveFile(
        dialogTitle: "Please select an output file:",
        fileName: "path.robi_script.json");

    if (result == null) return;

    final file = File(result);

    RobiPathSerializer.saveToFile(file, instructions);

    setState(() => focusedFile = file);
  }
}
