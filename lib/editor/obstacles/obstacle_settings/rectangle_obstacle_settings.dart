import 'package:flutter/material.dart';
import 'package:path_pilot/editor/obstacles/obstacle_settings/obstacle_settings_container.dart';

import '../obstacle.dart';

class RectangleObstacleSettings extends StatelessWidget {
  final RectangleObstacle obstacle;
  final void Function(Obstacle obstacle) onObstacleChanged;

  const RectangleObstacleSettings({
    super.key,
    required this.obstacle,
    required this.onObstacleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ObstacleSettingsContainer(
      obstacle: obstacle,
      onObstacleChanged: onObstacleChanged,
      children: [
        TextFormField(
          initialValue: (obstacle.x * 100).toStringAsFixed(2),
          decoration: const InputDecoration(labelText: 'X in cm'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            obstacle.x = (double.tryParse(value) ?? 0) / 100;
            onObstacleChanged(obstacle);
          },
        ),
        TextFormField(
          initialValue: (obstacle.y * 100).toStringAsFixed(2),
          decoration: const InputDecoration(labelText: 'Y in cm'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            obstacle.y = (double.tryParse(value) ?? 0) / 100;
            onObstacleChanged(obstacle);
          },
        ),
        TextFormField(
          initialValue: (obstacle.w * 100).toStringAsFixed(2),
          decoration: const InputDecoration(labelText: 'Width in cm'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            obstacle.w = (double.tryParse(value) ?? 0) / 100;
            onObstacleChanged(obstacle);
          },
        ),
        TextFormField(
          initialValue: (obstacle.h * 100).toStringAsFixed(2),
          decoration: const InputDecoration(labelText: 'Height in cm'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            obstacle.h = (double.tryParse(value) ?? 0) / 100;
            onObstacleChanged(obstacle);
          },
        ),
      ],
    );
  }
}
