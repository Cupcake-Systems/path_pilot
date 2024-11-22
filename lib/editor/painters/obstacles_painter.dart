import 'dart:ui';

import 'package:path_pilot/editor/painters/abstract_painter.dart';

import '../obstacles/obstacle.dart';

class ObstaclesPainter extends MyPainter {
  final Canvas canvas;
  final List<Obstacle> obstacles;
  final Rect visibleArea;

  ObstaclesPainter({
    required this.canvas,
    required this.obstacles,
    required this.visibleArea,
  });

  @override
  void paint() {
    for (final obstacle in obstacles) {
      if (obstacle.isVisible(visibleArea)) {
        canvas.save();
        obstacle.draw(canvas);
        canvas.restore();
      }
    }
  }
}
