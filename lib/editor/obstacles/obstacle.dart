import 'package:flutter/material.dart';

abstract class Obstacle {
  final Paint paint;
  static Paint get defaultPaint => Paint()..color = Colors.grey;

  const Obstacle({required this.paint});

  void draw(final Canvas canvas);

  ObstacleType get type;
  String get name => getName(type);

  Map<String, dynamic> toJson();

  static IconData getIcon(ObstacleType type) {
    switch (type) {
      case ObstacleType.rectangle:
        return Icons.square;
      case ObstacleType.circle:
        return Icons.circle;
    }
  }

  static String getName(ObstacleType type) {
    switch (type) {
      case ObstacleType.rectangle:
      case ObstacleType.circle:
        return "${type.name[0].toUpperCase()}${type.name.substring(1)}";
    }
  }

  String get details;

  bool isVisible(final Rect visibleArea);
}

class RectangleObstacle extends Obstacle {
  Rect rect;

  RectangleObstacle({
    required super.paint,
    required this.rect,
  });

  @override
  void draw(final Canvas canvas) {
    canvas.drawRect(rect, paint);
  }

  RectangleObstacle.fromJson(Map<String, dynamic> json)
      : rect = Rect.fromLTWH(
          json["x"],
          json["y"],
          json["w"],
          json["h"],
        ),
        super(paint: Paint()..color = Color(json["color"]));

  @override
  Map<String, dynamic> toJson() {
    return {
      "color": paint.color.value,
      "x": rect.left,
      "y": rect.top,
      "w": rect.width,
      "h": rect.height,
    };
  }

  @override
  ObstacleType get type => ObstacleType.rectangle;

  static RectangleObstacle base() => RectangleObstacle(paint: Obstacle.defaultPaint, rect: Rect.fromCircle(center: Offset.zero, radius: 0.1));

  @override
  String get details =>
      "Top left corner: (${(rect.left * 100).toStringAsFixed(2)}, ${(rect.top * 100).toStringAsFixed(2)})cm\nWidth: ${(rect.width * 100).toStringAsFixed(2)}cm\nHeight: ${(rect.height * 100).toStringAsFixed(2)}cm";

  @override
  bool isVisible(Rect visibleArea) => true;
}

class CircleObstacle extends Obstacle {
  Offset center;
  double radius;

  CircleObstacle({
    required super.paint,
    required this.center,
    required this.radius,
  });

  @override
  void draw(final Canvas canvas) => canvas.drawCircle(center, radius, paint);

  @override
  Map<String, dynamic> toJson() => {
        "color": paint.color.value,
        "x": center.dx,
        "y": center.dy,
        "r": radius,
      };

  CircleObstacle.fromJson(Map<String, dynamic> json)
      : center = Offset(json["x"], json["y"]),
        radius = json["r"],
        super(paint: Paint()..color = Color(json["color"]));

  @override
  ObstacleType get type => ObstacleType.circle;

  static CircleObstacle base() => CircleObstacle(paint: Obstacle.defaultPaint, center: Offset.zero, radius: 0.1);

  @override
  String get details =>
      "Center: (${(center.dx * 100).toStringAsFixed(2)}, ${(center.dy * 100).toStringAsFixed(2)})cm\nRadius: ${(radius * 100).toStringAsFixed(2)}cm";

  @override
  bool isVisible(Rect visibleArea) {
    return true;
  }
}



enum ObstacleType {
  rectangle,
  circle,
}
