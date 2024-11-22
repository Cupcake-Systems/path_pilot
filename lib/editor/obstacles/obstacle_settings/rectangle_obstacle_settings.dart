import 'package:flutter/material.dart';
import 'package:path_pilot/editor/obstacles/obstacle_settings/obstacle_settings_container.dart';

import '../../../helper/geometry.dart';
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
          initialValue: (obstacle.rect.left * 100).toStringAsFixed(2),
          decoration: const InputDecoration(labelText: 'X in cm'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            obstacle.rect = copyRectWith(obstacle.rect, left: (double.tryParse(value) ?? 0) / 100);
            onObstacleChanged(obstacle);
          },
        ),
        TextFormField(
          initialValue: (obstacle.rect.top * 100).toStringAsFixed(2),
          decoration: const InputDecoration(labelText: 'Y in cm'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            obstacle.rect = copyRectWith(obstacle.rect, top: (double.tryParse(value) ?? 0) / 100);
            onObstacleChanged(obstacle);
          },
        ),
        TextFormField(
          initialValue: (obstacle.rect.width * 100).toStringAsFixed(2),
          decoration: const InputDecoration(labelText: 'Width in cm'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            obstacle.rect = copyRectWith(obstacle.rect, width: (double.tryParse(value) ?? 0) / 100);
            onObstacleChanged(obstacle);
          },
        ),
        TextFormField(
          initialValue: (obstacle.rect.height * 100).toStringAsFixed(2),
          decoration: const InputDecoration(labelText: 'Height in cm'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            obstacle.rect = copyRectWith(obstacle.rect, height: (double.tryParse(value) ?? 0) / 100);
            onObstacleChanged(obstacle);
          },
        ),
      ],
    );
  }
}
