import 'package:flutter/material.dart';
import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/file_browser.dart';

import '../editor/robi_config.dart';
import '../robi_api/robi_utils.dart';

class RobiConfigSettingsPage extends StatefulWidget {
  final void Function(RobiConfig selectedConfig) onConfigSelected;
  final RobiConfig selectedConfig;

  const RobiConfigSettingsPage({super.key, required this.onConfigSelected, required this.selectedConfig});

  @override
  State<RobiConfigSettingsPage> createState() => _RobiConfigSettingsPageState();
}

class _RobiConfigSettingsPageState extends State<RobiConfigSettingsPage> {
  late RobiConfig selectedConfig = widget.selectedConfig;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Robi Configs"),
      ),
      body: ListView(
        children: [
          const Divider(height: 1),
          RadioListTile(
            title: Text(defaultRobiConfig.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            value: defaultRobiConfig,
            groupValue: selectedConfig,
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () => viewRobiConfigDialog(defaultRobiConfig),
              ),
            ),
            onChanged: (value) => selectConfig(value ?? defaultRobiConfig),
          ),
          const Divider(height: 1),
          for (final config in RobiConfigStorage.configs) ...[
            RadioListTile<RobiConfig>(
              groupValue: selectedConfig,
              value: config,
              onChanged: (value) => selectConfig(value ?? defaultRobiConfig),
              title: Text(config.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () => viewRobiConfigDialog(config),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) {
                            return RobiConfigurator(
                              initialConfig: config,
                              title: "Edit ${config.name}",
                              addedConfig: (c) {
                                final i = RobiConfigStorage.configs.indexOf(config);
                                RobiConfigStorage.remove(config);
                                RobiConfigStorage.configs.insert(i, c);
                                selectConfig(c);
                              },
                            );
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      RobiConfigStorage.remove(config);
                      selectConfig(defaultRobiConfig);
                    },
                    icon: const Icon(Icons.delete),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ],
      ),
      floatingActionButton: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => RobiConfigurator(
              initialConfig: defaultRobiConfig,
              title: "New Configuration",
              addedConfig: (config) => setState(() => RobiConfigStorage.add(config)),
            ),
          );
        },
        label: const Text("Add"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void selectConfig(RobiConfig config) {
    setState(() {
      selectedConfig = config;
    });
    widget.onConfigSelected(config);
  }

  void viewRobiConfigDialog(RobiConfig config) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(config.name),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Wheel radius: ${config.wheelRadius * 100}cm"),
                Text("Track width: ${config.trackWidth * 100}cm"),
                Text("Vertical Distance Wheel to IR: ${config.distanceWheelIr * 100}cm"),
                Text("Distance between IR sensors: ${config.irDistance * 100}cm"),
                Text("Wheel width: ${config.wheelWidth * 100}cm"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
}
