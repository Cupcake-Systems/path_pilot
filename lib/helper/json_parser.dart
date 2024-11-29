import 'dart:convert';

import 'package:flutter/foundation.dart';

class JsonParser {
  static dynamic parse(String json) => jsonDecode(json);

  static String stringify(Object? data) => jsonEncode(data);

  static Future<dynamic> parseIsolated(String json) => compute(parse, json);

  static Future<String> stringifyIsolated(Object? data) => compute(stringify, data);
}