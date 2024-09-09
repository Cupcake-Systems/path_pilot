import 'package:flutter/material.dart';
import 'package:robi_line_drawer/app_storage.dart';
import 'package:robi_line_drawer/file_browser.dart';

import '../editor/robi_config.dart';

class RobiConfigSettingsPage extends StatefulWidget {
  const RobiConfigSettingsPage({super.key});

  @override
  State<RobiConfigSettingsPage> createState() => _RobiConfigSettingsPageState();
}

class _RobiConfigSettingsPageState extends State<RobiConfigSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Robi Configs"),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(defaultRobiConfig.name),
            trailing: IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("Default Config"),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Wheel radius: ${defaultRobiConfig.wheelRadius * 100}cm"),
                            Text("Track width: ${defaultRobiConfig.trackWidth * 100}cm"),
                            Text("Vertical Distance Wheel to IR: ${defaultRobiConfig.distanceWheelIr * 100}cm"),
                            Text("Distance between IR sensors: ${defaultRobiConfig.irDistance * 100}cm"),
                            Text("Wheel width: ${defaultRobiConfig.wheelWidth * 100}cm"),
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
              },
            ),
          ),
          for (final config in RobiConfigStorage.configs) ...[
            ListTile(
              title: Text(config.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => RobiConfigurator(
                          initialConfig: config,
                          addedConfig: (c) {
                            setState(() {
                              final i = RobiConfigStorage.configs.indexOf(config);
                              RobiConfigStorage.remove(config);
                              RobiConfigStorage.configs.insert(i, c);
                            });
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => setState(() => RobiConfigStorage.remove(config)),
                    icon: const Icon(Icons.delete),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => RobiConfigurator(
              addedConfig: (config) => setState(() => RobiConfigStorage.add(config)),
            ),
          );
        },
        label: const Text("Add"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
