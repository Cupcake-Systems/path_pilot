import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';

String? Function(String? value) notEmptyValidator = (value) {
  if (value == null || value.isEmpty) return "Enter a value";
  return null;
};

String? Function(String? value) numberValidator = (value) {
  if (value == null || value.isEmpty) return "Enter a value";
  if (double.tryParse(value) == null) return "Enter a number";
  return null;
};

final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

class RobiConfigurator extends StatefulWidget {
  final void Function(RobiConfig config) addedConfig;
  final RobiConfig initialConfig;
  final String title;

  const RobiConfigurator({
    super.key,
    required this.addedConfig,
    required this.initialConfig,
    required this.title,
  });

  @override
  State<RobiConfigurator> createState() => _RobiConfiguratorState();
}

class _RobiConfiguratorState extends State<RobiConfigurator> {
  late double wheelRadius = widget.initialConfig.wheelRadius,
      trackWidth = widget.initialConfig.trackWidth,
      distanceWheelIr = widget.initialConfig.distanceWheelIr,
      wheelWidth = widget.initialConfig.wheelWidth,
      irDistance = widget.initialConfig.irDistance;

  late String name = widget.initialConfig.name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
              icon: const Icon(Icons.help),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) {
                      return Scaffold(
                        appBar: AppBar(
                          title: const Text("Robi Config Help"),
                        ),
                        body: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(
                            child: Image(
                              image: AssetImage("assets/robi_illustration_bottom_labeled.webp"),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          autovalidateMode: AutovalidateMode.always,
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: "Name"),
                validator: notEmptyValidator,
                onChanged: (value) {
                  if (value.isNotEmpty) name = value;
                },
              ),
              TextFormField(
                initialValue: (wheelRadius * 100).toStringAsFixed(2),
                decoration: const InputDecoration(labelText: "Wheel Radius (cm)"),
                validator: numberValidator,
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) wheelRadius = parsed / 100;
                },
              ),
              TextFormField(
                initialValue: (trackWidth * 100).toStringAsFixed(2),
                decoration: const InputDecoration(labelText: "Track Width (cm)"),
                validator: numberValidator,
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) trackWidth = parsed / 100;
                },
              ),
              TextFormField(
                initialValue: (distanceWheelIr * 100).toStringAsFixed(2),
                decoration: const InputDecoration(labelText: "Distance Wheel to IR (cm)"),
                validator: numberValidator,
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) distanceWheelIr = parsed / 100;
                },
              ),
              TextFormField(
                initialValue: (wheelWidth * 100).toStringAsFixed(2),
                decoration: const InputDecoration(labelText: "Wheel Width (cm)"),
                validator: numberValidator,
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) wheelWidth = parsed / 100;
                },
              ),
              TextFormField(
                initialValue: (irDistance * 100).toStringAsFixed(2),
                decoration: const InputDecoration(labelText: "IR Distance between sensors (cm)"),
                validator: numberValidator,
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  if (parsed != null) irDistance = parsed / 100;
                },
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) return;
                      widget.addedConfig(
                        RobiConfig(
                          name: name,
                          wheelRadius: wheelRadius,
                          trackWidth: trackWidth,
                          distanceWheelIr: distanceWheelIr,
                          wheelWidth: wheelWidth,
                          irDistance: irDistance,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    label: const Text("Done"),
                    icon: const Icon(Icons.done),
                  ),
                  if (!Platform.isAndroid) const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    label: const Text("Cancel"),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
