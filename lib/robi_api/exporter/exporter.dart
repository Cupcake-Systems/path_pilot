import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:path_pilot/helper/file_manager.dart';
import 'package:path_pilot/robi_api/exporter/exporter_instructions.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';

class Exported {
  final RobiConfig config;
  final List<InstructionResult> instructionResults;

  Exported(this.config, this.instructionResults);

  List<Map<String, dynamic>> toJson() => instructionResults.map((e) {
        final exported = e.export();
        return exported.toJson()..addAll({"ty": exportedObjectMapper(exported)});
      }).toList();

  static String exportedObjectMapper(ExportedMissionInstruction instruction) {
    if (instruction is ExportedDriveInstruction) return "d";
    if (instruction is ExportedRapidTurnInstruction) return "rt";
    if (instruction is ExportedTurnInstruction) return "t";
    throw UnsupportedError("");
  }
}

class Exporter {
  static final GZipCodec gzipCompressor = GZipCodec(
    level: ZLibOption.maxLevel,
    windowBits: 8,
    memLevel: ZLibOption.maxMemLevel,
  );

  static String encode(RobiConfig config, List<InstructionResult> instructions) {
    final exported = Exported(config, instructions).toJson();
    return jsonEncode(exported);
  }

  static Uint8List encodeAndCompress(RobiConfig config, List<InstructionResult> instructions) {
    final enCodedJson = ascii.encode(encode(config, instructions));
    final gZipJson = gzipCompressor.encode(enCodedJson);
    return Uint8List.fromList(gZipJson);
  }

  static Future<void> exportToFile(RobiConfig config, List<InstructionResult> instructions, BuildContext context) {
    return pickFileAndWriteWithStatusMessage(
      bytes: encodeAndCompress(config, instructions),
      context: context,
      extension: ".json.gz",
    );
  }
}
