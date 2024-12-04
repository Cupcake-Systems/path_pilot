import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_pilot/app_storage.dart';

import '../backend_api/submit_log.dart';
import '../helper/dialogs.dart';
import '../main.dart';

const availableFrameRates = [10, 30, 60];
const availableAutoSaveIntervals = [1, 2, 5, 10, 15, 30];
const availableSaveTriggers = {
  AppLifecycleState.paused,
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
};
const saveTriggerNames = {
  AppLifecycleState.paused: "app pause",
  AppLifecycleState.inactive: "focus loss",
  AppLifecycleState.hidden: "minimized",
};

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.titleSmall!.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer);

    return Scaffold(
      appBar: AppBar(title: const Text("Preferences")),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Visualizer", style: headerStyle),
          ),
          SwitchListTile(
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text("Limit Simulation Frame Rate to ", style: TextStyle(fontSize: 16)),
                DropdownButton<int>(
                    value: SettingsStorage.visualizerFps,
                    onChanged: SettingsStorage.limitFps
                        ? (value) => setState(
                              () => SettingsStorage.visualizerFps = value ?? SettingsStorage.visualizerFps,
                            )
                        : null,
                    items: [
                      if (!availableFrameRates.contains(SettingsStorage.visualizerFps))
                        DropdownMenuItem(
                          value: SettingsStorage.visualizerFps,
                          child: Text("${SettingsStorage.visualizerFps} FPS"),
                        ),
                      for (final frameRate in availableFrameRates)
                        DropdownMenuItem(
                          value: frameRate,
                          child: Text("$frameRate FPS"),
                        ),
                    ]),
              ],
            ),
            subtitle: const Text("Adjust the frame rate for smoother or more energy-efficient simulations."),
            value: SettingsStorage.limitFps,
            onChanged: (value) => setState(() => SettingsStorage.limitFps = value),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text("Show Milliseconds"),
            subtitle: const Text("Toggle whether to display milliseconds in timelines."),
            value: SettingsStorage.showMilliseconds,
            onChanged: (value) => setState(() => SettingsStorage.showMilliseconds = value),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Save", style: headerStyle),
          ),
          SwitchListTile(
            value: SettingsStorage.autoSave,
            onChanged: (value) => setState(() => SettingsStorage.autoSave = value),
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text("Auto-Save every "),
                DropdownButton<int>(
                  value: SettingsStorage.autoSaveInterval,
                  onChanged: SettingsStorage.autoSave ? (value) => setState(() => SettingsStorage.autoSaveInterval = value ?? 2) : null,
                  items: [
                    for (final interval in availableAutoSaveIntervals.toSet().toList(growable: false)..sort())
                      DropdownMenuItem(
                        value: interval,
                        child: Text("$interval"),
                      ),
                  ],
                ),
                const Text(" minutes"),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final trigger in availableSaveTriggers)
            CheckboxListTile(
              title: Text("Save on ${saveTriggerNames[trigger]}"),
              value: SettingsStorage.saveTriggers.contains(trigger),
              onChanged: (value) => setState(() {
                if (value == true) {
                  SettingsStorage.addSaveTrigger(trigger);
                } else {
                  SettingsStorage.removeSaveTrigger(trigger);
                }
              }),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Error Reporting", style: headerStyle),
          ),
          SwitchListTile(
            title: const Text("Send Anonymous Logs"),
            subtitle: const Text("Automatically send anonymous log files to developers when an error occurs."),
            value: SettingsStorage.sendLog,
            onChanged: (value) => setState(() => SettingsStorage.sendLog = value),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text("Send Log to Developers"),
            subtitle: const Text("Tap to manually send the current log file to the developers."),
            trailing: const Icon(Icons.send),
            enabled: !isSubmitting,
            onTap: () async {
              if (isSubmitting) return;

              final conf = await confirmDialog(context, "Send Log", "Are you sure you want to send the log to the developers?");
              if (!conf) return;

              logger.info("User requested to send log");

              setState(() => isSubmitting = true);
              final success = await submitLog(logFile);
              setState(() => isSubmitting = false);

              showSnackBar(success ? "Log sent successfully" : "Failed to send log");
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text("Advanced", style: headerStyle),
          ),
          SwitchListTile(
            title: const Text("Developer Mode"),
            subtitle: const Text("Enable advanced debugging tools and additional features."),
            value: SettingsStorage.developerMode,
            onChanged: (value) {
              logger.info("User ${value ? "enabled" : "disabled"} developer mode");
              setState(() {
                SettingsStorage.developerMode = value;
              });
            },
          ),
          const Divider(height: 1),
          ListTile(
            trailing: IconButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: PreservingStorage.userId.toString()));
                showSnackBar("User ID copied to clipboard");
              },
              icon: const Icon(Icons.copy),
            ),
            title: const Text("Your User ID"),
            subtitle: Wrap(
              spacing: 8,
              children: [
                const Text("Copy this ID to share it with the developers for support."),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.red,
                  ),
                  child: const Text(
                    "Do not share it with anyone else!",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
