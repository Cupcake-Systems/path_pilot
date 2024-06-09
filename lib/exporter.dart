import 'dart:convert';
import 'dart:io';

import 'package:robi_line_drawer/robi_path_serializer.dart';
import 'package:robi_line_drawer/robi_utils.dart';

class Exported {
  final RobiConfig config;
  final List<InstructionContainer> instructions;

  Exported(this.config, this.instructions);

  Exported.fromJson(Map<String, dynamic> json)
      : config = RobiConfig.fromJson(json["config"]),
        instructions = (json["instructions"] as List)
            .map((e) => InstructionContainer.fromJson(e))
            .toList();

  Map<String, dynamic> toJson() => {
        "config": config.toJson(),
        "instructions": instructions.map((e) => e.toJson()).toList(),
      };
}

class Exporter {
  static String encode(
      RobiConfig config, List<MissionInstruction> instructions) {
    final exported = Exported(
            config, instructions.map((e) => InstructionContainer(e)).toList())
        .toJson();

    return jsonEncode(exported);
  }

  static Future<File> saveToFile(File file, RobiConfig config,
          List<MissionInstruction> instructions) =>
      file.writeAsString(encode(config, instructions));
}
