import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_pilot/helper/file_manager.dart';
import 'package:path_pilot/robi_api/robi_path_serializer.dart';

import '../robi_api/robi_utils.dart';

final class SaveData {
  final List<MissionInstruction> instructions;

  const SaveData({required this.instructions});

  static const SaveData empty = SaveData(instructions: []);

  static SaveData? fromJson(String json) {
    final data = jsonDecode(json);
    try {
      final instructions = RobiPathSerializer.decode(data["instructions"]);
      if (instructions == null) return null;
      return SaveData(instructions: instructions.toList());
    } catch (e) {
      return null;
    }
  }

  static Future<SaveData?> fromFileWithStatusMessage(String path, BuildContext context) async {
    final json = await readStringFromFileWithStatusMessage(path, context);
    if (json == null) return null;
    return fromJson(json);
  }

  String toJson() {
    final saveData = {
      "instructions": RobiPathSerializer.encode(instructions),
    };
    return jsonEncode(saveData);
  }

  Uint8List toBytes() {
    return utf8.encode(toJson());
  }

  Future<File?> saveToFileWithStatusMessage(String path, BuildContext context) {
    return writeStringToFileWithStatusMessage(path, toJson(), context);
  }

  SaveData copyWith({List<MissionInstruction>? instructions}) {
    return SaveData(instructions: instructions ?? this.instructions);
  }
}
