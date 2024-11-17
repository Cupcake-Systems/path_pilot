import 'package:flutter/material.dart';
import 'package:path_pilot/app_storage.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Preferences")),
      body: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Visualizer", style: Theme.of(context).textTheme.headlineSmall),
                  const Divider(),
                  ListTile(
                    leading: const Text("Simulation Frame Rate"),
                    title: Slider(
                      value: SettingsStorage.visualizerFps.toDouble(),
                      onChanged: (value) {
                        setState(() {
                          SettingsStorage.visualizerFps = value.round();
                        });
                      },
                      min: 1,
                      max: 60,
                      divisions: 59,
                      label: "${SettingsStorage.visualizerFps} FPS",
                    ),
                  ),
                  ListTile(
                    title: const Text("Show Milliseconds"),
                    trailing: Switch(
                      value: SettingsStorage.showMilliseconds,
                      onChanged: (value) => setState(() => SettingsStorage.showMilliseconds = value),
                    ),
                  )
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Advanced", style: Theme.of(context).textTheme.headlineSmall),
                  const Divider(),
                  ListTile(
                    title: const Text("Developer Mode"),
                    trailing: Switch(
                      value: SettingsStorage.developerMode,
                      onChanged: (value) => setState(() {
                        SettingsStorage.developerMode = value;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
