import 'obstacle.dart';

class ObstaclesSerializer {
  static List<Map<String, dynamic>> encode(List<Obstacle> obstacles) => obstacles
      .map((obstacle) => {
            ...obstacle.toJson(),
            "type": obstacle.type.name,
          })
      .toList();

  static Iterable<Obstacle> decode(List json) sync* {
    for (final obstacleJson in json) {
      try {
        switch (getObstacleTypeFromString(obstacleJson["type"])) {
          case ObstacleType.rectangle:
            yield RectangleObstacle.fromJson(obstacleJson);
          case ObstacleType.circle:
            yield CircleObstacle.fromJson(obstacleJson);
          default:
            throw UnsupportedError("Unknown obstacle type");
        }
      } catch (e) {
        // ignore
      }
    }
  }

  static ObstacleType getObstacleTypeFromString(String s) {
    for (final element in ObstacleType.values) {
      if (element.name == s) return element;
    }
    throw UnsupportedError("Unknown obstacle type");
  }
}
