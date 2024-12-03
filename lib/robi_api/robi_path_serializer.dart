import 'package:path_pilot/editor/add_instruction_dialog.dart';
import 'package:path_pilot/main.dart';
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
  static List<Map<String, dynamic>> encode(List<MissionInstruction> instructions) {
    final List<InstructionContainer> containers = [];
    for (final inst in instructions) {
      containers.add(InstructionContainer(inst));
    }
    return containers.map((e) => e.toJson()).toList(growable: false);
  }

  static Iterable<MissionInstruction> decode(List json) sync* {
    for (final e in json) {
      try {
        yield InstructionContainer.fromJson(e).instruction;
      } catch (e, s) {
        logger.errorWithStackTrace("Failed to decode instruction\nJSON: $json", e, s);
      }
    }
  }
}
