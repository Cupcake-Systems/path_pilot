import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:path_pilot/helper/file_manager.dart';
import 'package:path_pilot/helper/json_parser.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';

final class Exported {
  final RobiConfig config;
  final List<InstructionResult> instructionResults;

  const Exported(this.config, this.instructionResults);

  List<Map<String, dynamic>> toJson() => instructionResults.map((e) => e.export().toJson()).toList();
}

class Exporter {
  static final GZipCodec gzipCompressor = GZipCodec(
    level: ZLibOption.maxLevel,
    windowBits: 8,
    memLevel: ZLibOption.maxMemLevel,
  );

  static Future<String> encode(RobiConfig config, List<InstructionResult> instructions) {
    final exported = Exported(config, instructions).toJson();
    return JsonParser.stringifyIsolated(exported);
  }

  static Future<Uint8List> encodeAndCompress(RobiConfig config, List<InstructionResult> instructions) async {
    final enCodedJson = ascii.encode(await encode(config, instructions));
    final gZipJson = gzipCompressor.encode(enCodedJson);
    return Uint8List.fromList(gZipJson);
  }

  static Future<File?> exportToFile(RobiConfig config, List<InstructionResult> instructions, BuildContext context) async {
    final bytes = await encodeAndCompress(config, instructions);
    if (!context.mounted) return null;
    return await pickFileAndWriteWithStatusMessage(
      bytes: bytes,
      context: context,
      extension: ".json.gz",
    );
  }
}
