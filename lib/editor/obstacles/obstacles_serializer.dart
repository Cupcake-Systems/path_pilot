import 'package:path_pilot/main.dart';

import 'obstacle.dart';

class ObstaclesSerializer {
  static List<Map<String, dynamic>> encode(List<Obstacle> obstacles) => obstacles
      .map((obstacle) => {
            ...obstacle.toJson(),
            "type": obstacle.type.name,
          })
      .toList();

  static Stream<Obstacle> decode(List json) async* {
    for (final obstacleJson in json) {
      try {
        switch (getObstacleTypeFromString(obstacleJson["type"])) {
          case ObstacleType.rectangle:
            yield RectangleObstacle.fromJson(obstacleJson);
            break;
          case ObstacleType.circle:
            yield CircleObstacle.fromJson(obstacleJson);
            break;
          case ObstacleType.image:
            final json = await ImageObstacle.fromJson(obstacleJson);
            if (json != null) yield json;
            break;
        }
      } catch (e, s) {
        logger.errorWithStackTrace("Failed to decode obstacle\nJSON: $json", e, s);
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
