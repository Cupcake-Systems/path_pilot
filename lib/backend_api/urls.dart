import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_pilot/backend_api/secrets.dart' as secrets;

import '../app_storage.dart';

const protocol = kDebugMode? "http" : "https";
const domain = kDebugMode? "localhost:8951" : "path-pilot.cupcake-systems.com";
final userId = PreservingStorage.userId;

const submitLogPath = "/logs/submit";
const submitLogUrl = "$protocol://$domain$submitLogPath";

final identificationHeader = {
  "Authorization": "Bearer ${userId.toString()}",
};

Map get validationHeader => {"validation-token": generateSecureKey()};

String generateSecureKey({int length = 16}) {
  if (length < 16) {
    throw ArgumentError("Key length must be at least 16 characters.");
  }

  // Generate random part of the key
  final random = Random.secure();
  final randomBytes = List<int>.generate(length ~/ 2, (_) => random.nextInt(256));
  final randomPart = base64UrlEncode(randomBytes).substring(0, length ~/ 2);

  // Create HMAC signature
  final hmac = Hmac(sha256, utf8.encode(secrets.validationKey));
  final signature = base64UrlEncode(hmac.convert(utf8.encode(randomPart)).bytes).substring(0, 8);

  return "$randomPart$signature";
}

