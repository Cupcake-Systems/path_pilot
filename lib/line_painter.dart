import 'dart:math';

import 'package:flutter/material.dart';
import 'package:robi_line_drawer/robi_utils.dart';
import 'package:vector_math/vector_math.dart';


class LinePainter extends CustomPainter {
  late SimulationResult simulationResult;
  final double scale;
  final RobiConfig robiConfig;
  static const double strokeWidth = 5;
  late Simulater simulater;

  LinePainter(
      List<MissionInstruction> instructions, this.scale, this.robiConfig) {
    simulater = Simulater(robiConfig);
    simulationResult = simulater.calculate(instructions);
  }

  @override
  void paint(Canvas canvas, Size size) {
    InstructionResult prevResult = DriveResult(0, 0, Vector2.zero(), 0);

    for (InstructionResult result in simulationResult.instructionResults) {
      if (result is DriveResult) {
        drawDrive(prevResult, result, canvas);
      } else if (result is TurnResult) {
        drawTurn(prevResult, result, canvas);
      }

      prevResult = result;
    }
  }

  void drawDrive(InstructionResult prevInstructionResult,
      DriveResult instructionResult, Canvas canvas) {
    List<Color> colors = [
      velocityToColor(prevInstructionResult.managedVelocity),
      velocityToColor(instructionResult.managedVelocity)
    ];

    final accelerationPaint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        radius: 0.5 * (1 / sqrt2),
      ).createShader(Rect.fromCircle(
          center: vecToOffset(prevInstructionResult.endPosition),
          radius: instructionResult.accelerationDistance * scale))
      ..strokeWidth = strokeWidth;

    canvas.drawLine(vecToOffset(prevInstructionResult.endPosition),
        vecToOffset(instructionResult.endPosition), accelerationPaint);
  }

  void drawTurn(InstructionResult prevInstructionResult, TurnResult instruction,
      Canvas canvas) {
    final paint = Paint()
      ..color = velocityToColor(prevInstructionResult.managedVelocity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final degree =
        (prevInstructionResult.endRotation - instruction.endRotation).abs();
    final left = prevInstructionResult.endRotation < instruction.endRotation;

    final path = drawCirclePart(
        instruction.turnRadius,
        degree,
        prevInstructionResult.endRotation,
        prevInstructionResult.endPosition,
        left);
    canvas.drawPath(path, paint);
  }

  Path drawCirclePart(
      double radius, double degree, double rotation, Vector2 offset, bool left) {

    double startAngle = 360 - rotation - 90;
    double sweepAngle = degree;

    Vector2 center;

    if (left) {
      startAngle = -rotation + (90 - degree);
      center = offset + Vector2(
          cosD(rotation + 90) * radius, -sinD(rotation + 90) * radius);
    } else {
      center = offset + Vector2(
          -cosD(rotation + 90) * radius, sinD(rotation + 90) * radius);
    }

    return Path()
      ..arcTo(Rect.fromCircle(center: vecToOffset(center), radius: radius * scale),
          startAngle * (pi / 180), sweepAngle * (pi / 180), false);
  }

  Color velocityToColor(double velocity) {
    int r = (velocity / simulationResult.maxTargetedVelocity * 255).round();
    int g = 255 - r;
    return Color.fromARGB(255, r, g, 0);
  }

  Offset vecToOffset(Vector2 vec) => Offset(vec.x * scale, vec.y * scale);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
