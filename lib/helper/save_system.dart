import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_pilot/editor/obstacles/obstacle.dart';
import 'package:path_pilot/helper/file_manager.dart';
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
      final data = jsonDecode(json);
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

  static Future<SaveData?> fromFileWithStatusMessage(String path, BuildContext context) async {
    final json = await readStringFromFileWithStatusMessage(path, context);
    if (json == null) return null;
    return fromJson(json);
  }

  String toJson() {
    final saveData = {
      "instructions": RobiPathSerializer.encode(instructions),
      "obstacles": ObstaclesSerializer.encode(obstacles),
    };
    return jsonEncode(saveData);
  }

  Uint8List toBytes() {
    return utf8.encode(toJson());
  }

  Future<File?> saveToFileWithStatusMessage(String path, BuildContext context) {
    return writeStringToFileWithStatusMessage(path, toJson(), context);
  }

  SaveData copyWith({List<MissionInstruction>? instructions, List<Obstacle>? obstacles}) {
    return SaveData(
      instructions: instructions ?? this.instructions,
      obstacles: obstacles ?? this.obstacles,
    );
  }
}
