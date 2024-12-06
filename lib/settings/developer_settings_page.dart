import 'package:flutter/material.dart';
import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/backend_api/urls.dart';
import 'package:path_pilot/helper/dialogs.dart';

import '../logger/log_viewer.dart';
import '../main.dart';

class DeveloperSettingsPage extends StatefulWidget {
  const DeveloperSettingsPage({super.key});

  @override
  State<DeveloperSettingsPage> createState() => _DeveloperSettingsPageState();
}

class _DeveloperSettingsPageState extends State<DeveloperSettingsPage> {
  final TextEditingController _backendUrlController = TextEditingController(text: DeveloperSettings.backendUrl);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Developer Settings")),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text("Log"),
            subtitle: const Text("View the app log"),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LogViewer(logFile: logFile),
                ),
              );
            },
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _backendUrlController,
                    onChanged: (s) {
                      final url = Uri.tryParse(s);
                      if (url == null) return;
                    },
                    onEditingComplete: saveBackendUrl,
                    validator: (s) => getValidUrl(s).$1,
                    autovalidateMode: AutovalidateMode.always,
                    decoration: const InputDecoration(
                      hintText: "https://example.com",
                      label: Text("Backend URL"),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: saveBackendUrl, icon: const Icon(Icons.save)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    DeveloperSettings.backendUrl = apiUrl;
                    setState(() {
                      _backendUrlController.text = apiUrl;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String? errorMsg, String? url) getValidUrl(String? s) {
    if (s == null) return ("URL cannot be null", null);
    if (s.isEmpty) return ("URL cannot be empty", null);

    final url = Uri.tryParse(s);

    if (url == null) return ("Invalid URL", null);

    final urlString = url.toString();

    if (!urlString.startsWith("http://") && !urlString.startsWith("https://")) return ("URL must start with http or https", null);
    if (url.host.isEmpty) return ("URL must have a host", null);
    if (url.path.isNotEmpty) return ("URL must not have a path", null);

    return (null, urlString);
  }

  void saveBackendUrl() {
    final validUrl = getValidUrl(_backendUrlController.text).$2;
    if (validUrl == null) return;
    DeveloperSettings.backendUrl = validUrl;
    showSnackBar("Backend URL updated");
  }
}
