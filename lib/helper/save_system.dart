import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_pilot/editor/obstacles/obstacle.dart';
import 'package:path_pilot/helper/dialogs.dart';
import 'package:path_pilot/helper/file_manager.dart';
import 'package:path_pilot/helper/json_parser.dart';
import 'package:path_pilot/robi_api/robi_path_serializer.dart';

import '../editor/obstacles/obstacles_serializer.dart';
import '../robi_api/robi_utils.dart';

final class SaveData {
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
    } catch (e) {
      return null;
    }
  }

  static Future<SaveData?> fromFileWithStatusMessage(String path) async {
    final json = await readStringFromFileWithStatusMessage(path);
    if (json == null) {
      showSnackBar("Failed to decode data from $path");
      return null;
    }
    if (json.isEmpty) return SaveData.empty;
    return fromJson(json);
  }

  Future<String> toJson() {
    final saveData = {
      "instructions": RobiPathSerializer.encode(instructions),
      "obstacles": ObstaclesSerializer.encode(obstacles),
    };
    return JsonParser.stringifyIsolated(saveData);
  }

  Future<Uint8List> toBytes() async {
    return utf8.encode(await toJson());
  }

  Future<File?> saveToFileWithStatusMessage(String path) async {
    final json = await toJson();
    return writeStringToFileWithStatusMessage(path, json);
  }

  SaveData copyWith({List<MissionInstruction>? instructions, List<Obstacle>? obstacles}) {
    return SaveData(
      instructions: instructions ?? this.instructions,
      obstacles: obstacles ?? this.obstacles,
    );
  }
}
