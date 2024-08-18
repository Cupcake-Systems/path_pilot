import 'dart:convert';

import 'package:robi_line_drawer/file_browser.dart';
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
  static const String _lastUsedKey = "LastUsedConfig";

  static late final List<RobiConfig> _storedConfigs;
  static late int _lastUsedConfigIndex;

  static RobiConfig get lastUsedConfig => _storedConfigs[_lastUsedConfigIndex];

  static set lastUsedConfigIndex(int i) {
    _lastUsedConfigIndex = i;
    _saveLastUsedConfig();
  }

  static int get length => _storedConfigs.length;

  static void init() {
    _storedConfigs = _loadConfigs();
    _lastUsedConfigIndex = _loadLastUsedConfig();
    if (_lastUsedConfigIndex >= _storedConfigs.length) _lastUsedConfigIndex = 0;
  }

  static List<RobiConfig> _loadConfigs() {
    try {
      final storedString = AppData._prefs.getString(_storageKey);
      if (storedString == null) return [defaultRobiConfig];
      final List jsonList = jsonDecode(storedString) as List;
      return jsonList.map((e) => RobiConfig.fromJson(e)).toList();
    } catch (e) {
      return [defaultRobiConfig];
    }
  }

  static int _loadLastUsedConfig() => AppData._prefs.getInt(_lastUsedKey) ?? 0;

  static void _saveLastUsedConfig() =>
      AppData._prefs.setInt(_lastUsedKey, _lastUsedConfigIndex);

  static void _saveConfigs() {
    final jsonString =
        jsonEncode(_storedConfigs.map((e) => e.toJson()).toList());
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
