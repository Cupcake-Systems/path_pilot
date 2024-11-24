import 'package:flutter/material.dart';
import 'package:path_pilot/editor/obstacles/obstacle_settings/obstacle_settings_container.dart';

import '../obstacle.dart';

class CircleObstacleSettings extends StatelessWidget {
  final CircleObstacle obstacle;
  final void Function(Obstacle obstacle) onObstacleChanged;

  const CircleObstacleSettings({
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
          decoration: const InputDecoration(labelText: 'Center X in cm'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            obstacle.x = (double.tryParse(value) ?? 0) / 100;
            onObstacleChanged(obstacle);
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: (obstacle.y * 100).toStringAsFixed(2),
          decoration: const InputDecoration(labelText: 'Center Y in cm'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            obstacle.y = (double.tryParse(value) ?? 0) / 100;
            onObstacleChanged(obstacle);
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: (obstacle.radius * 100).toStringAsFixed(2),
          decoration: const InputDecoration(labelText: 'Radius in cm'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            obstacle.radius = (double.tryParse(value) ?? 0) / 100;
            onObstacleChanged(obstacle);
          },
        ),
      ],
    );
  }
}
