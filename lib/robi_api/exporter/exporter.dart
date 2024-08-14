import 'dart:convert';
import 'dart:io';

import 'package:robi_line_drawer/robi_api/exporter/exporter_instructions.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';

class Exported {
  final RobiConfig config;
  final List<InstructionResult> instructionResults;

  Exported(this.config, this.instructionResults);

  Map<String, dynamic> toJson() => {
        "config": config.toJson(),
        "instructions": instructionResults.map((e) {
          final exported = e.export();
          return exported.toJson()
            ..addAll({"type": exportedObjectMapper(exported)});
        }).toList(),
      };

  static String exportedObjectMapper(ExportedMissionInstruction instruction) {
    if (instruction is ExportedDriveInstruction) return "drive";
    if (instruction is ExportedTurnInstruction) return "turn";
    if (instruction is ExportedRapidTurnInstruction) return "rapid_turn";
    throw UnsupportedError("");
  }
}

class Exporter {
  static String encode(
      RobiConfig config, List<InstructionResult> instructions) {
    final exported = Exported(config, instructions).toJson();

    return jsonEncode(exported);
  }

  static Future<File> saveToFile(File file, RobiConfig config,
          List<InstructionResult> instructions) =>
      file.writeAsString(encode(config, instructions));
}
