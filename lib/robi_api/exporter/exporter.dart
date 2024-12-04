import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_pilot/helper/file_manager.dart';
import 'package:path_pilot/helper/json_parser.dart';
import 'package:path_pilot/main.dart';
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

  static Future<File?> exportToFileWithStatusMessage(RobiConfig config, List<InstructionResult> instructions, String filePath) async {
    logger.info("Exporting ${instructions.length} instructions to file: $filePath");
    final bytes = await encodeAndCompress(config, instructions);
    return writeBytesToFileWithStatusMessage(filePath, bytes, showFilePathInMessage: true);
  }
}
