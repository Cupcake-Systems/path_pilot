import 'package:vector_math/vector_math.dart';

class RamerDouglasPeucker {
  static List<Vector2> ramerDouglasPeucker(final List<Vector2> points, final double epsilon) {
    if (points.length < 3) return points;

    // Find the point with the maximum distance
    double dmax = 0;
    int index = 0;

    for (int i = 1; i < points.length - 1; i++) {
      double d = perpendicularDistanceSqr(points[i], points[0], points[points.length - 1]);
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }

    // If max distance is greater than epsilon, recursively simplify
    if (dmax > epsilon * epsilon) { // Square epsilon to avoid sqrt calculation
      List<Vector2> recResults1 = ramerDouglasPeucker(points.sublist(0, index + 1), epsilon);
      List<Vector2> recResults2 = ramerDouglasPeucker(points.sublist(index, points.length), epsilon);

      // Merge results
      return [...recResults1.sublist(0, recResults1.length - 1), ...recResults2];
    } else {
      return [points[0], points[points.length - 1]];
    }
  }

  static double perpendicularDistanceSqr(final Vector2 point, final Vector2 lineStart, final Vector2 lineEnd) {
    final lineVector = lineEnd - lineStart;
    final pointVector = point - lineStart;

    if (lineVector.length2 == 0) {
      return point.distanceToSquared(lineStart);
    }

    // Project pointVector onto lineVector to find the nearest point
    double t = pointVector.dot(lineVector) / lineVector.length2;
    t = t.clamp(0, 1);

    final nearestPoint = lineStart + lineVector * t;
    return point.distanceToSquared(nearestPoint);
  }
}
