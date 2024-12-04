import 'dart:async';
import 'dart:ui';

import 'package:path_pilot/helper/dialogs.dart';
import 'package:path_pilot/main.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';
import 'package:path_pilot/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helper/json_parser.dart';

class AppData {
  static late final SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await RobiConfigStorage.init();
  }
}

class RobiConfigStorage {
  static const String _storageKey = "RobiConfigs";

  static late final List<RobiConfig> _storedConfigs;

  static int get length => _storedConfigs.length;

  static List<RobiConfig> get configs => _storedConfigs;

  static Future<void> init() async {
    _storedConfigs = await _loadConfigs();
  }

  static Future<List<RobiConfig>> _loadConfigs() async {
    try {
      final storedString = AppData._prefs.getString(_storageKey);
      if (storedString == null) return [];
      final List jsonList = await JsonParser.parseIsolated(storedString) as List;
      return jsonList.map((e) => RobiConfig.fromJson(e)).toList();
    } catch (e, s) {
      logger.errorWithStackTrace("Failed to load Robi configs", e, s);
      showSnackBar("Failed to load RobiConfigs: $e");
      return [];
    }
  }

  static void _saveConfigs() {
    final jsonString = JsonParser.stringify(_storedConfigs.map((e) => e.toJson()).toList());
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
  static const String _autoSaveKey = "autoSave";
  static const String _limitFpsKey = "limitFps";
  static const String _sendLogKey = "sendLog";

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

  static bool get autoSave => AppData._prefs.getBool(_autoSaveKey) ?? true;

  static set autoSave(bool value) => AppData._prefs.setBool(_autoSaveKey, value);

  static bool get limitFps => AppData._prefs.getBool(_limitFpsKey) ?? true;

  static set limitFps(bool value) => AppData._prefs.setBool(_limitFpsKey, value);

  static bool get sendLog => AppData._prefs.getBool(_sendLogKey) ?? true;

  static set sendLog(bool value) => AppData._prefs.setBool(_sendLogKey, value);
}

class PreservingStorage {
  static const String _shouldSubmitLogKey = "shouldSubmitLog";
  static const String _userIdKey = "userId";
  static const String _lastSubmittedLogTimeKey = "lastSubmittedLogTime";

  static bool get shouldSubmitLog => AppData._prefs.getBool(_shouldSubmitLogKey) ?? false;

  static set shouldSubmitLog(bool value) => AppData._prefs.setBool(_shouldSubmitLogKey, value);

  static int get userId => AppData._prefs.getInt(_userIdKey) ?? rand.nextInt(4294967296);

  static DateTime? get lastSubmittedLogTime {
    final time = AppData._prefs.getInt(_lastSubmittedLogTimeKey);
    if (time == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(time);
  }

  static set lastSubmittedLogTime(DateTime? value) {
    if (value == null) {
      AppData._prefs.remove(_lastSubmittedLogTimeKey);
      return;
    }
    AppData._prefs.setInt(_lastSubmittedLogTimeKey, value.millisecondsSinceEpoch);
  }
}
