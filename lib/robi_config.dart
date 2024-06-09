import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robi_line_drawer/robi_utils.dart';

class RobiConfigurator extends StatelessWidget {
  final void Function(RobiConfig config) addedConfig;
  final int index;

  const RobiConfigurator(
      {super.key, required this.addedConfig, required this.index});

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(builder: (context, setState) {
      final formKey = GlobalKey<FormState>();
      final radiusController = TextEditingController(text: "3.5");
      final trackController = TextEditingController(text: "14.7");
      final nameController = TextEditingController(text: "Config ${index + 1}");

      return AlertDialog(
        title: const Text("Add Robi Configuration"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration:
                    const InputDecoration(label: Text("Configuration Name")),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Enter a value";
                  return null;
                },
              ),
              Flexible(
                child: Row(
                  children: [
                    const Text("Wheel radius: "),
                    Expanded(
                      child: TextFormField(
                        controller: radiusController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^(\d+)?\.?\d{0,2}'))
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter a value";
                          } else if (double.tryParse(value) == null) {
                            return "Enter a number";
                          }
                          return null;
                        },
                      ),
                    ),
                    const Text("cm")
                  ],
                ),
              ),
              Flexible(
                child: Row(
                  children: [
                    const Text("Track width: "),
                    Expanded(
                      child: TextFormField(
                        controller: trackController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^(\d+)?\.?\d{0,2}'))
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter a value";
                          } else if (double.tryParse(value) == null) {
                            return "Enter a number";
                          }
                          return null;
                        },
                      ),
                    ),
                    const Text("cm")
                  ],
                ),
              ),
            ],
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
              addedConfig(RobiConfig(
                double.parse(radiusController.text) / 100.0,
                double.parse(trackController.text) / 100.0,
                name: nameController.text,
              ));
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      );
    });
  }
}
