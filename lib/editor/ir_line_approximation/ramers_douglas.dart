import 'dart:math';

import 'package:vector_math/vector_math.dart';

class RamerDouglasPeucker {
  static List<Point<double>> ramerDouglasPeucker(
      List<Point<double>> points, double epsilon) {
    if (points.length < 3) {
      return points;
    }

    // Find the point with the maximum distance
    double dmax = 0;
    int index = 0;

    for (int i = 1; i < points.length - 1; i++) {
      double d = perpendicularDistance(
          points[i], points[0], points[points.length - 1]);
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }

    // If max distance is greater than epsilon, recursively simplify
    if (dmax > epsilon) {
      // Recursive call
      List<Point<double>> recResults1 =
          ramerDouglasPeucker(points.sublist(0, index + 1), epsilon);
      List<Point<double>> recResults2 =
          ramerDouglasPeucker(points.sublist(index, points.length), epsilon);

      // Build the result list
      return [
        ...recResults1.sublist(0, recResults1.length - 1),
        ...recResults2
      ];
    } else {
      return [points[0], points[points.length - 1]];
    }
  }

  static double perpendicularDistance(
      Point<double> point, Point<double> lineStart, Point<double> lineEnd) {
    double dx = lineEnd.x - lineStart.x;
    double dy = lineEnd.y - lineStart.y;

    if (dx == 0 && dy == 0) {
      // The line segment is a point
      return sqrt(
          pow(point.x - lineStart.x, 2) + pow(point.y - lineStart.y, 2));
    }

    double t = ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) /
        (dx * dx + dy * dy);
    t = max(0, min(1, t));

    double nearestX = lineStart.x + t * dx;
    double nearestY = lineStart.y + t * dy;

    return sqrt(pow(point.x - nearestX, 2) + pow(point.y - nearestY, 2));
  }
}

// Ramer-Douglas-Peucker algorithm

List<Vector2> pointsToVector2(List<Point<double>> points) =>
    points.map((e) => Vector2(e.x, e.y)).toList();

List<Point<double>> vectorsToPoints(List<Vector2> vecs) =>
    vecs.map((e) => Point(e.x, e.y)).toList();
