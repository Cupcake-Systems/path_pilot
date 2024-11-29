import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_pilot/file_browser.dart';
import 'package:path_pilot/helper/dialogs.dart';

get fileSystemShortcuts => getShortcuts();

List<FilesystemPickerShortcut> getShortcuts() {
  if (Platform.isAndroid) {
    final documentsDir = Directory("/storage/emulated/0/Documents");
    final downloadDir = Directory("/storage/emulated/0/Download");

    return [
      FilesystemPickerShortcut(name: "Internal storage", path: Directory("/storage/emulated/0"), icon: Icons.storage),
      if (documentsDir.existsSync()) FilesystemPickerShortcut(name: "Documents", path: documentsDir, icon: Icons.description),
      if (downloadDir.existsSync()) FilesystemPickerShortcut(name: "Download", path: downloadDir, icon: Icons.download),
    ];
  } else if (Platform.isLinux) {
    final userName = Platform.environment["USER"];

    final homeDir = Directory("/home");
    final userNameDir = Directory("/home/$userName");
    final documentsDir = Directory("/home/$userName/Documents");
    final downloadsDir = Directory("/home/$userName/Downloads");

    return [
      FilesystemPickerShortcut(name: "/", path: Directory("/"), icon: Icons.storage),
      if (userNameDir.existsSync())
        FilesystemPickerShortcut(name: "Home", path: userNameDir, icon: Icons.home)
      else if (homeDir.existsSync())
        FilesystemPickerShortcut(name: "/home", path: homeDir, icon: Icons.home),
      if (documentsDir.existsSync()) FilesystemPickerShortcut(name: "Documents", path: documentsDir, icon: Icons.description),
      if (downloadsDir.existsSync()) FilesystemPickerShortcut(name: "Downloads", path: downloadsDir, icon: Icons.download),
    ];
  } else if (Platform.isWindows) {
    final userName = Platform.environment["USERNAME"];

    final drives = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").map((e) => Directory("$e:/")).where((e) => e.existsSync()).toList();

    return [
      for (final drive in drives) ...[
        FilesystemPickerShortcut(
          name: drive.path,
          path: drive,
          icon: Icons.storage,
        ),
        if (Directory("${drive.path}/Users/$userName").existsSync()) ...[
          FilesystemPickerShortcut(
            name: "Home",
            path: Directory("${drive.path}/Users/$userName"),
            icon: Icons.home,
          ),
          if (Directory("${drive.path}/Users/$userName/Documents").existsSync())
            FilesystemPickerShortcut(
              name: "Documents",
              path: Directory("${drive.path}/Users/$userName/Documents"),
              icon: Icons.description,
            ),
          if (Directory("${drive.path}/Users/$userName/Downloads").existsSync())
            FilesystemPickerShortcut(
              name: "Downloads",
              path: Directory("${drive.path}/Users/$userName/Downloads"),
              icon: Icons.download,
            )
        ] else if (Directory("${drive.path}/Users").existsSync())
          FilesystemPickerShortcut(
            name: "Users",
            path: Directory("${drive.path}/Users"),
            icon: Icons.people,
          ),
      ],
    ];
  } else {
    throw UnsupportedError("Unsupported platform");
  }
}

Future<File?> writeBytesToFileWithStatusMessage(
  String path,
  List<int> content, {
  bool showFilePathInMessage = false,
  String? successMessage,
}) async {
  try {
    final file = File(path);
    final f = await compute(file.writeAsBytes, content);
    String msg = successMessage ?? "File written successfully";
    if (showFilePathInMessage) {
      msg = "$msg to \"$path\"";
    }
    showSnackBar(msg, duration: const Duration(seconds: 2));
    return f;
  } catch (e) {
    showSnackBar("Failed to write to $path: $e");
    return null;
  }
}

Future<File?> writeStringToFileWithStatusMessage(
  String path,
  String content, {
  bool showFilePathInMessage = false,
  String? successMessage,
}) {
  return writeBytesToFileWithStatusMessage(path, utf8.encode(content), showFilePathInMessage: showFilePathInMessage, successMessage: successMessage);
}

final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

Future<File?> pickFileAndWriteWithStatusMessage(
    {required Uint8List bytes, required BuildContext context, required String extension, bool showFilePathInMessage = false, String? successMessage, bool overwriteWarning = true}) async {
  final hasPermission = await getExternalStoragePermission();

  if (!hasPermission) {
    showSnackBar("Please grant storage permission");
    return null;
  }

  if (!extension.startsWith(".")) {
    extension = ".$extension";
  }

  if (!context.mounted) return null;

  String? fileName = await showDialog<String?>(
    context: context,
    builder: (context) {
      final controller = TextEditingController();
      return AlertDialog(
        title: const Text("Enter file name"),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: "File name", suffix: Text(extension)),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\.\-_]")),
            ],
            validator: (s) {
              if (s == null || s.isEmpty) {
                return "Please enter a file name";
              }
              return null;
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.of(context).pop(controller.text);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.of(context).pop(controller.text);
            },
            child: const Text("Ok"),
          ),
        ],
      );
    },
  );

  if (fileName == null || fileName.isEmpty) return null;

  final directoryPath = await FilePicker.platform.getDirectoryPath();

  if (directoryPath == null) return null;

  final filePath = "$directoryPath/$fileName$extension";

  final file = File(filePath);

  if (overwriteWarning && await file.exists()) {
    if (!context.mounted) return null;
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("File already exists"),
          content: const Text("Do you want to overwrite it?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Overwrite"),
            ),
          ],
        );
      },
    );

    if (overwrite == null || !overwrite) return null;
  }

  return writeBytesToFileWithStatusMessage(
    filePath,
    bytes,
    showFilePathInMessage: showFilePathInMessage,
    successMessage: successMessage,
  );
}

Directory? lastDirectory;

Future<String?> pickSingleFile({
  String? dialogTitle,
  Directory? initialDirectory,
  List<String>? allowedExtensions,
  required BuildContext context,
}) async {
  if (allowedExtensions != null) {
    for (int i = 0; i < allowedExtensions.length; i++) {
      if (!allowedExtensions[i].startsWith(".")) {
        allowedExtensions[i] = ".${allowedExtensions[i]}";
      }
    }
  }

  initialDirectory ??= lastDirectory;
  lastDirectory = initialDirectory;

  final filePath = await FilesystemPicker.openDialog(
    context: context,
    pickText: dialogTitle,
    shortcuts: fileSystemShortcuts,
    fsType: FilesystemType.file,
    allowedExtensions: allowedExtensions,
    fileTileSelectMode: FileTileSelectMode.wholeTile,
    directory: initialDirectory,
    requestPermission: () => getExternalStoragePermission(),
  );
  return filePath;
}

Future<Uint8List?> readBytesFromFileWithWithStatusMessage(String path) async {
  try {
    final f = File(path);
    return await f.readAsBytes();
  } catch (e) {
    showSnackBar("Failed to read from $path: $e");
    return null;
  }
}

Future<String?> readStringFromFileWithStatusMessage(String path) async {
  final bytes = await readBytesFromFileWithWithStatusMessage(path);
  if (bytes == null) return null;
  return utf8.decode(bytes);
}
