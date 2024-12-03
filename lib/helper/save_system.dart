import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_pilot/editor/obstacles/obstacle.dart';
import 'package:path_pilot/helper/dialogs.dart';
import 'package:path_pilot/helper/file_manager.dart';
import 'package:path_pilot/helper/json_parser.dart';
import 'package:path_pilot/main.dart';
import 'package:path_pilot/robi_api/robi_path_serializer.dart';

import '../editor/obstacles/obstacles_serializer.dart';
import '../robi_api/robi_utils.dart';

final class SaveData {
  static const compatibleFileVersion = 1;

  final List<MissionInstruction> instructions;
  final List<Obstacle> obstacles;

  const SaveData({
    required this.instructions,
    required this.obstacles,
  });

  static const SaveData empty = SaveData(instructions: [], obstacles: []);

  static Future<SaveData?> fromJson(String json) async {
    try {
      final data = await JsonParser.parseIsolated(json);

      final versionNumber = data["version"];

      if (versionNumber == null) {
        showSnackBar("Version number not found in data");
        return null;
      }

      if (versionNumber is! int) {
        showSnackBar("Version number is not an integer: $versionNumber");
        return null;
      }

      switch (versionNumber) {
        case 1:
          final instructions = data["instructions"];
          final obstacles = data["obstacles"];

          List<MissionInstruction> decodedInstructions = [];
          List<Obstacle> decodedObstacles = [];

          if (instructions != null) {
            decodedInstructions = RobiPathSerializer.decode(instructions).toList(growable: false);
          }
          if (obstacles != null) {
            decodedObstacles = await ObstaclesSerializer.decode(obstacles).toList();
          }

          return SaveData(
            instructions: decodedInstructions,
            obstacles: decodedObstacles,
          );
        default:
          showSnackBar("Unknown version number: $versionNumber");
          return null;
      }
    } catch (e, s) {
      logger.errorWithStackTrace("Failed to decode save data\nJSON string: $json", e, s);
      return null;
    }
  }

  static Future<SaveData?> fromFileWithStatusMessage(String path) async {
    final parsed = await readStringFromFileWithStatusMessage(path);

    if (parsed == null) return null;

    if (parsed.isEmpty) return SaveData.empty;

    final json = await fromJson(parsed);
    if (json == null) {
      showSnackBar("Failed to decode data from $path");
      return null;
    }

    return json;
  }

  Future<String> toJson() {
    final saveData = {
      "version": compatibleFileVersion,
      "instructions": RobiPathSerializer.encode(instructions),
      "obstacles": ObstaclesSerializer.encode(obstacles),
    };
    return JsonParser.stringifyIsolated(saveData);
  }

  Future<Uint8List> toBytes() async {
    return utf8.encode(await toJson());
  }

  Future<File?> saveToFileWithStatusMessage(String path, {bool showSuccessMessage = true}) async {
    final json = await toJson();
    return writeStringToFileWithStatusMessage(
      path,
      json,
      showSuccessMessage: showSuccessMessage,
      successMessage: "Data saved successfully",
    );
  }

  SaveData copyWith({List<MissionInstruction>? instructions, List<Obstacle>? obstacles}) {
    return SaveData(
      instructions: instructions ?? this.instructions,
      obstacles: obstacles ?? this.obstacles,
    );
  }
}
