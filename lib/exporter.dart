import 'dart:convert';
import 'dart:io';

import 'package:robi_line_drawer/robi_api/robi_utils.dart';

class Exported {
  final RobiConfig config;
  final List<MissionInstruction> instructions;

  Exported(this.config, this.instructions);

  Map<String, dynamic> toJson() => {
        "config": config.toJson(),
        "instructions": instructions
            .map((e) => e.basic.toJson()
              ..addAll({"type": (e.basic is BaseDriveInstruction ? "drive" : "turn")}))
            .toList(),
      };
}

class Exporter {
  static String encode(
      RobiConfig config, List<MissionInstruction> instructions) {
    final exported = Exported(config, instructions).toJson();

    return jsonEncode(exported);
  }

  static Future<File> saveToFile(File file, RobiConfig config,
          List<MissionInstruction> instructions) =>
      file.writeAsString(encode(config, instructions));
}
