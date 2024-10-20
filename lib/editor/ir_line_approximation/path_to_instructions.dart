import 'dart:math';

import 'package:robi_line_drawer/robi_api/simulator.dart';
import 'package:vector_math/vector_math.dart';

import '../../robi_api/robi_utils.dart';

class PathToInstructions {
  static List<MissionInstruction> calculate(List<Vector2> irPathApproximation) {
    List<MissionInstruction> instructions = [];
    Vector2 a, b;
    a = Vector2(1, 0);
    double rotation = 0;

    Vector2 prevPoint = irPathApproximation[0];

    for (int i = 1; i < irPathApproximation.length; ++i) {
      final point = irPathApproximation[i];
      final distance = point.distanceTo(prevPoint);

      b = point - prevPoint;

      double alpha = acos(a.dot(b) / (a.length * b.length)) * 180 / pi;
      a = b;

      if (alpha.abs() < 0.0001) continue;

      if (point.distanceTo(polarToCartesian(alpha + rotation, distance) + prevPoint) > 0.0001) {
        alpha *= -1;
      }

      rotation += alpha;

      final turnInstruction = RapidTurnInstruction(
        left: alpha > 0,
        turnDegree: alpha.abs(),
        acceleration: 0.1,
        targetVelocity: 0.2,
      );

      final driveInstruction = DriveInstruction(
        targetVelocity: 0.2,
        acceleration: 0.3,
        targetFinalVelocity: 0,
        targetDistance: prevPoint.distanceTo(point),
      );

      instructions += [turnInstruction, driveInstruction];
      prevPoint = point;
    }

    return instructions;
  }
}
