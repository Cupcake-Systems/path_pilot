import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:path_pilot/robi_api/robi_utils.dart';
import 'package:path_pilot/settings/settings.dart';
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

class SettingsStorage {
  static const String _developerModeKey = "developerMode";
  static const String _visualizerFpsKey = "visualizerFps";
  static const String _showMillisecondsKey = "showMilliseconds";
  static const String _saveOnTriggerKey = "saveOnTrigger";
  static const String _autoSaveIntervalKey = "autoSaveInterval";
  static const String _autoSave = "autoSave";
  static bool _autoSaveRunning = false;

  static void startAutoSaveTimer(void Function() saveTrigger) async {
    if (_autoSaveRunning) return;
    _autoSaveRunning = true;
    while (_autoSaveRunning) {
      await Future.delayed(Duration(minutes: autoSaveInterval));
      if (autoSave) {
        saveTrigger();
      }
    }
  }

  static void stopAutoSaveTimer() => _autoSaveRunning = false;

  static final Set<AppLifecycleState> _autoSaveTriggers =
      AppData._prefs.getStringList(_saveOnTriggerKey)?.map((e) => AppLifecycleState.values.firstWhere((element) => element.name == e)).toSet() ?? availableSaveTriggers;

  static bool get developerMode => AppData._prefs.getBool(_developerModeKey) ?? false;

  static set developerMode(bool value) => AppData._prefs.setBool(_developerModeKey, value);

  static int get visualizerFps => AppData._prefs.getInt(_visualizerFpsKey) ?? 30;

  static set visualizerFps(int value) => AppData._prefs.setInt(_visualizerFpsKey, value);

  static bool get showMilliseconds => AppData._prefs.getBool(_showMillisecondsKey) ?? false;

  static set showMilliseconds(bool value) => AppData._prefs.setBool(_showMillisecondsKey, value);

  static Set<AppLifecycleState> get saveTriggers => _autoSaveTriggers;

  static void addSaveTrigger(AppLifecycleState state) {
    _autoSaveTriggers.add(state);
    _saveSaveTriggers();
  }

  static void removeSaveTrigger(AppLifecycleState state) {
    _autoSaveTriggers.remove(state);
    _saveSaveTriggers();
  }

  static Future<bool> _saveSaveTriggers() {
    final List<String> stringList = _autoSaveTriggers.map((e) => e.name).toList();
    return AppData._prefs.setStringList(_saveOnTriggerKey, stringList);
  }

  static int get autoSaveInterval => AppData._prefs.getInt(_autoSaveIntervalKey) ?? 2;

  static set autoSaveInterval(int value) => AppData._prefs.setInt(_autoSaveIntervalKey, value);

  static bool get autoSave => AppData._prefs.getBool(_autoSave) ?? true;

  static set autoSave(bool value) => AppData._prefs.setBool(_autoSave, value);
}
