import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_pilot/backend_api/secrets.dart' as secrets;

import '../app_storage.dart';

const apiUrl = kDebugMode? "http://localhost:8951" : "https://path-pilot.cupcake-systems.com";
final userId = PreservingStorage.userId;
String get userSetApiUrl => DeveloperSettings.backendUrl;

const submitLogPath = "logs/submit";
String get submitLogUrl => "$userSetApiUrl/$submitLogPath";

final identificationHeader = Map.unmodifiable({
  "Authorization": "Bearer ${userId.toString()}",
});

Map get validationHeader => Map.unmodifiable({"validation-token": generateSecureKey()});

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

