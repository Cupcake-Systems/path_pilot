import 'package:flutter/material.dart';
import 'package:robi_line_drawer/file_browser.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';

class RobiConfigurator extends StatelessWidget {
  final void Function(RobiConfig config) addedConfig;
  final int index;

  const RobiConfigurator({super.key, required this.addedConfig, required this.index});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final controllers = _initControllers(index);

    return AlertDialog(
      title: const Text("Add Robi Configuration"),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: controllers['name']!,
                label: "Configuration Name",
                validator: (value) {
                  if (value == null || value.isEmpty) return "Enter a value";
                  return null;
                },
              ),
              const SizedBox(height: 8),
              ..._buildMeasurementFields(controllers),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            final config = RobiConfig(
              double.parse(controllers['radius']!.text) / 100.0,
              double.parse(controllers['track']!.text) / 100.0,
              double.parse(controllers['distanceWheelIR']!.text) / 100.0,
              double.parse(controllers['wheelWidth']!.text) / 100.0,
              double.parse(controllers['irDistance']!.text) / 100.0,
              name: controllers['name']!.text,
            );
            addedConfig(config);
            Navigator.pop(context);
          },
          child: const Text("Add"),
        ),
      ],
    );
  }

  Map<String, TextEditingController> _initControllers(int index) {
    return {
      'radius': TextEditingController(text: "${defaultRobiConfig.wheelRadius * 100}"),
      'track': TextEditingController(text: "${defaultRobiConfig.trackWidth * 100}"),
      'distanceWheelIR': TextEditingController(text: "${defaultRobiConfig.distanceWheelIr * 100}"),
      'wheelWidth': TextEditingController(text: "${defaultRobiConfig.wheelWidth * 100}"),
      'irDistance': TextEditingController(text: "${defaultRobiConfig.irDistance * 100}"),
      'name': TextEditingController(text: "Config ${index + 1}"),
    };
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }

  List<Widget> _buildMeasurementFields(Map<String, TextEditingController> controllers) {
    const fields = [
      {"label": "Wheel radius", "key": "radius"},
      {"label": "Track width", "key": "track"},
      {"label": "Vertical Distance Wheel to IR", "key": "distanceWheelIR"},
      {"label": "Distance between IR sensors", "key": "irDistance"},
      {"label": "Wheel width", "key": "wheelWidth"},
    ];

    return fields.map((field) {
      final key = field['key']!;
      final label = field['label']!;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: controllers[key]!,
                label: "$label (cm)",
                validator: (value) {
                  if (value == null || value.isEmpty) return "Enter a value";
                  if (double.tryParse(value) == null) return "Enter a number";
                  return null;
                },
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
