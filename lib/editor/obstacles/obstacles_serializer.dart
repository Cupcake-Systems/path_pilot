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
        switch (ObstacleType.fromString(obstacleJson["type"])) {
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
}
