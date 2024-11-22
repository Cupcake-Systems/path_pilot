import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

import '../obstacle.dart';

class ObstacleSettingsContainer extends StatefulWidget {
  final Obstacle obstacle;
  final List<Widget> children;
  final void Function(Obstacle newObstacle) onObstacleChanged;

  const ObstacleSettingsContainer({
    super.key,
    required this.obstacle,
    required this.children,
    required this.onObstacleChanged,
  });

  @override
  State<ObstacleSettingsContainer> createState() => _ObstacleSettingsContainerState();
}

class _ObstacleSettingsContainerState extends State<ObstacleSettingsContainer> {
  late final obstacle = widget.obstacle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...widget.children,
        ColorPicker(
          onColorChanged: (Color color) {
            setState(() => obstacle.paint.color = color);
            widget.onObstacleChanged(obstacle);
          },
          color: obstacle.paint.color,
          title: const Text('Obstacle Color'),
          pickersEnabled: {
            ColorPickerType.primary: true,
            ColorPickerType.accent: false,
            ColorPickerType.wheel: true,
          },
          enableShadesSelection: false,
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
