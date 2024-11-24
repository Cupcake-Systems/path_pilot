import 'package:flutter/material.dart';
import 'package:path_pilot/app_storage.dart';

const availableFrameRates = [10, 30, 60];
const availableAutoSaveIntervals = [1, 2, 5, 10, 15, 30];
const availableSaveTriggers = [
  AppLifecycleState.paused,
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
];
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
          ListTile(
            title: const Text("Simulation Frame Rate", style: TextStyle(fontSize: 16)),
            subtitle: const Text("Adjust the frame rate for smoother or more energy-efficient simulations."),
            trailing: DropdownButton<int>(value: SettingsStorage.visualizerFps, onChanged: (value) => setState(() => SettingsStorage.visualizerFps = value!), items: [
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
            title: Row(
              children: [
                const Text("Auto-Save every "),
                DropdownButton<int>(
                  value: SettingsStorage.autoSaveInterval,
                  onChanged: (value) => setState(() => SettingsStorage.autoSaveInterval = value ?? 2),
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
            child: Text("Advanced", style: headerStyle),
          ),
          SwitchListTile(
            title: const Text("Developer Mode"),
            subtitle: const Text("Enable advanced debugging tools and additional features."),
            value: SettingsStorage.developerMode,
            onChanged: (value) => setState(() {
              SettingsStorage.developerMode = value;
            }),
          ),
        ],
      ),
    );
  }
}
