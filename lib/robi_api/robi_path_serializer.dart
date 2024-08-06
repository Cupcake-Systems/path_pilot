import 'dart:convert';
import 'dart:io';

import 'package:robi_line_drawer/editor/add_instruction_dialog.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart';

final startResult = DriveResult(
  startRotation: 0,
  endRotation: 0,
  startPosition: Vector2.zero(),
  endPosition: Vector2.zero(),
  initialVelocity: 0,
  maxVelocity: 0,
  finalVelocity: 0,
  accelerationEndPoint: Vector2.zero(),
  decelerationStartPoint: Vector2.zero(),
);

class InstructionContainer {
  late final UserInstruction type;
  late final MissionInstruction instruction;

  static UserInstruction getInstructionTypeFromString(String s) {
    for (final element in UserInstruction.values) {
      if (element.name == s) return element;
    }
    throw UnsupportedError("");
  }

  InstructionContainer(this.instruction)
      : type = instructionToType(instruction);

  static UserInstruction instructionToType(MissionInstruction instruction) {
    if (instruction is DriveInstruction) {
      return UserInstruction.drive;
    } else if (instruction is AccelerateOverDistanceInstruction) {
      if (instruction.acceleration > 0) {
        return UserInstruction.accelerateOverDistance;
      } else {
        return UserInstruction.decelerateOverDistance;
      }
    } else if (instruction is AccelerateOverTimeInstruction) {
      if (instruction.acceleration > 0) {
        return UserInstruction.accelerateOverTime;
      } else {
        return UserInstruction.decelerateOverTime;
      }
    } else if (instruction is DriveForwardDistanceInstruction) {
      return UserInstruction.driveDistance;
    } else if (instruction is DriveForwardTimeInstruction) {
      return UserInstruction.driveTime;
    } else if (instruction is TurnInstruction) {
      return UserInstruction.turn;
    } else {
      throw UnsupportedError("");
    }
  }

  InstructionContainer.fromJson(Map<String, dynamic> json) {
    type = getInstructionTypeFromString(json["type"]);
    final instJson = json["instruction"];

    switch (type) {
      case UserInstruction.drive:
        instruction = DriveInstruction.fromJson(instJson);
        break;
      case UserInstruction.turn:
        instruction = TurnInstruction.fromJson(instJson);
        break;
      case UserInstruction.rapidTurn:
        instruction = RapidTurnInstruction.fromJson(instJson);
        break;
      case UserInstruction.accelerateOverDistance:
      case UserInstruction.decelerateOverDistance:
        instruction = AccelerateOverDistanceInstruction.fromJson(instJson);
        break;
      case UserInstruction.accelerateOverTime:
      case UserInstruction.decelerateOverTime:
        instruction = AccelerateOverTimeInstruction.fromJson(instJson);
        break;
      case UserInstruction.driveDistance:
        instruction = DriveForwardDistanceInstruction.fromJson(instJson);
        break;
      case UserInstruction.driveTime:
        instruction = DriveForwardTimeInstruction.fromJson(instJson);
        break;
    }
  }

  Map<String, dynamic> toJson() => {
        "type": type.name,
        "instruction": instruction.toJson(),
      };
}

class RobiPathSerializer {
  static Future<File> saveToFile(
          File file, List<MissionInstruction> instructions) =>
      file.writeAsString(encode(instructions));

  static String encode(List<MissionInstruction> instructions) {
    final List<InstructionContainer> containers = [];
    for (final inst in instructions) {
      containers.add(InstructionContainer(inst));
    }
    return jsonEncode(containers.map((e) => e.toJson()).toList());
  }

  static Iterable<MissionInstruction>? decode(String json) {
    try {
      final List<dynamic> decoded = jsonDecode(json);
      final parsed =
          decoded.map((e) => InstructionContainer.fromJson(e).instruction);
      return parsed;
    } on Exception {
      return null;
    }
  }
}
