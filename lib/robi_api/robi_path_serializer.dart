import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:path_pilot/editor/add_instruction_dialog.dart';
import 'package:path_pilot/helper/file_manager.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';

class InstructionContainer {
  late final UserInstruction type;
  late final MissionInstruction instruction;

  static UserInstruction getInstructionTypeFromString(String s) {
    for (final element in UserInstruction.values) {
      if (element.name == s) return element;
    }
    throw UnsupportedError("");
  }

  InstructionContainer(this.instruction) : type = instructionToType(instruction);

  static UserInstruction instructionToType(MissionInstruction instruction) {
    if (instruction is DriveInstruction) {
      return UserInstruction.drive;
    } else if (instruction is TurnInstruction) {
      return UserInstruction.turn;
    } else if (instruction is RapidTurnInstruction) {
      return UserInstruction.rapidTurn;
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
    }
  }

  Map<String, dynamic> toJson() => {
        "type": type.name,
        "instruction": instruction.toJson(),
      };
}

class RobiPathSerializer {
  static Future<void> saveToFile(String path, List<MissionInstruction> instructions, BuildContext context) {
    return writeStringToFileWithStatusMessage(path, encode(instructions), context);
  }

  static String encode(List<MissionInstruction> instructions) {
    final List<InstructionContainer> containers = [];
    for (final inst in instructions) {
      containers.add(InstructionContainer(inst));
    }
    return jsonEncode(containers.map((e) => e.toJson()).toList());
  }

  static Iterable<MissionInstruction>? decode(String json) {
    if (json.isEmpty) return const Iterable.empty();
    try {
      final List decoded = jsonDecode(json);
      final parsed = decoded.map((e) => InstructionContainer.fromJson(e).instruction);
      return parsed;
    } on Exception {
      return null;
    }
  }
}
