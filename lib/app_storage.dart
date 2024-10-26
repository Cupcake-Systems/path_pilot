import 'dart:convert';

import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppData {
  static late final SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    RobiConfigStorage.init();
  }
}

class RobiConfigStorage {
  static const String _storageKey = "RobiConfigs";

  static late final List<RobiConfig> _storedConfigs;

  static int get length => _storedConfigs.length;

  static List<RobiConfig> get configs => _storedConfigs;

  static void init() {
    _storedConfigs = _loadConfigs();
  }

  static List<RobiConfig> _loadConfigs() {
    try {
      final storedString = AppData._prefs.getString(_storageKey);
      if (storedString == null) return [];
      final List jsonList = jsonDecode(storedString) as List;
      return jsonList.map((e) => RobiConfig.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static void _saveConfigs() {
    final jsonString = jsonEncode(_storedConfigs.map((e) => e.toJson()).toList());
    AppData._prefs.setString(_storageKey, jsonString);
  }

  static void add(RobiConfig config) {
    _storedConfigs.add(config);
    _saveConfigs();
  }

  static void remove(RobiConfig config) {
    _storedConfigs.remove(config);
    _saveConfigs();
  }

  static int indexOf(RobiConfig config) => _storedConfigs.indexOf(config);

  static RobiConfig get(int index) => _storedConfigs[index];
}
