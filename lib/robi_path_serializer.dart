import 'dart:convert';
import 'dart:io';

import 'package:robi_line_drawer/robi_utils.dart';
import 'package:vector_math/vector_math.dart';

final startResult = DriveResult(0, 0, Vector2.zero(), 0);

class InstructionContainer {
  late final AvailableInstruction type;
  late final MissionInstruction instruction;

  static AvailableInstruction getInstructionTypeFromString(String s) {
    for (AvailableInstruction element in AvailableInstruction.values) {
      if (element.name == s) return element;
    }
    throw UnsupportedError("");
  }

  InstructionContainer(this.instruction) {
    if (instruction is DriveInstruction) {
      type = AvailableInstruction.driveInstruction;
    } else if (instruction is TurnInstruction) {
      type = AvailableInstruction.turnInstruction;
    } else {
      throw UnsupportedError("");
    }
  }

  InstructionContainer.fromJson(Map<String, dynamic> json) {
    type = getInstructionTypeFromString(json["type"]);
    if (type == AvailableInstruction.driveInstruction) {
      instruction = DriveInstruction.fromJson(json["instruction"]);
    } else if (type == AvailableInstruction.turnInstruction) {
      instruction = TurnInstruction.fromJson(json["instruction"]);
    } else {
      throw UnsupportedError("");
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
