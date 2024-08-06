import 'dart:math';

import 'package:curved_gradient/curved_gradient.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/abstract_painter.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../robi_api/robi_utils.dart';
import '../../robi_api/simulator.dart';

class SimulationPainter extends MyPainter {
  final SimulationResult simulationResult;
  final Canvas canvas;
  final Size size;
  final double strokeWidth;
  final InstructionResult? highlightedInstruction;

  late final yellowOutlinePaint = Paint()
    ..color = Colors.yellow
    ..strokeWidth = (strokeWidth + 0.01)
    ..style = PaintingStyle.stroke;

  SimulationPainter({
    required this.simulationResult,
    required this.canvas,
    required this.size,
    this.strokeWidth = 0.02,
    required this.highlightedInstruction,
  });

  @override
  void paint() {
    for (InstructionResult result in simulationResult.instructionResults) {
      if (result is DriveResult) {
        drawDrive(result);
      } else if (result is TurnResult) {
        drawTurn(result);
      }
    }
  }

  static Alignment polarToAlignment(double deg) =>
      Alignment(cosD(deg), -sinD(deg));

  void drawDrive(DriveResult instructionResult) {
    final accelerationPaint = Paint()
      ..shader = CurvedGradient(
        colors: [
          velocityToColor(instructionResult.initialVelocity),
          velocityToColor(instructionResult.maxVelocity),
        ],
        begin: Alignment.center,
        end: polarToAlignment(instructionResult.startRotation),
        granularity: 10,
        curveGenerator: (x) => sqrt(x),
      ).createShader(Rect.fromCircle(
          center: vecToOffset(instructionResult.startPosition),
          radius: instructionResult.startPosition
              .distanceTo(instructionResult.accelerationEndPoint)))
      ..strokeWidth = strokeWidth;

    final decelerationPaint = Paint()
      ..shader = CurvedGradient(
        colors: [
          velocityToColor(instructionResult.finalVelocity),
          velocityToColor(instructionResult.maxVelocity),
        ],
        begin: Alignment.center,
        end: polarToAlignment(instructionResult.startRotation),
        granularity: 10,
        curveGenerator: (x) => sqrt(1 - x),
      ).createShader(Rect.fromCircle(
          center: vecToOffset(instructionResult.decelerationStartPoint),
          radius: instructionResult.decelerationStartPoint
              .distanceTo(instructionResult.endPosition)))
      ..strokeWidth = strokeWidth;

    if (instructionResult == highlightedInstruction) {
      canvas.drawLine(vecToOffset(instructionResult.startPosition),
          vecToOffset(instructionResult.endPosition), yellowOutlinePaint);
    }

    // Draw the original line
    canvas.drawLine(
      vecToOffset(instructionResult.startPosition),
      vecToOffset(instructionResult.accelerationEndPoint),
      accelerationPaint,
    );
    canvas.drawLine(
      vecToOffset(instructionResult.accelerationEndPoint),
      vecToOffset(instructionResult.decelerationStartPoint),
      Paint()
        ..color = velocityToColor(instructionResult.maxVelocity)
        ..strokeWidth = strokeWidth,
    );
    canvas.drawLine(
      vecToOffset(instructionResult.decelerationStartPoint),
      vecToOffset(instructionResult.endPosition),
      decelerationPaint,
    );
  }

  void drawTurn(TurnResult instruction) {
    final degree = (instruction.endRotation - instruction.startRotation).abs();
    final left = instruction.startRotation < instruction.endRotation;

    List<Color> colors = [
      velocityToColor(instruction.initialVelocity),
      velocityToColor(instruction.finalVelocity)
    ];

    drawCirclePart(
        instruction.turnRadius,
        degree,
        instruction.startRotation,
        instruction.startPosition,
        left,
        canvas,
        size,
        colors,
        instruction == highlightedInstruction);
  }

  void drawCirclePart(
      double radius,
      double degree,
      double rotation,
      Vector2 offset,
      bool left,
      Canvas canvas,
      Size size,
      List<Color> colors,
      bool highlight) {
    double startAngle = 270 - rotation;
    double sweepAngle = degree % 360;

    Vector2 center = polarToCartesian(rotation + 90, radius);

    if (left) {
      startAngle -= 180 + degree;
    } else {
      center.y *= -1;
      center.x *= -1;
    }

    center += offset;

    final rect = Rect.fromCircle(center: vecToOffset(center), radius: radius);

    double o = startAngle;

    if (left) {
      colors = colors.reversed.toList();
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        colors: colors,
        stops: [0, degree / 360],
        transform: GradientRotation(o * (pi / 180)),
      ).createShader(rect);

    if (degree >= 360) {
      if (highlight) {
        canvas.drawCircle(vecToOffset(center), radius, yellowOutlinePaint);
      }
      canvas.drawCircle(vecToOffset(center), radius, paint);
    }

    if (highlight) {
      canvas.drawArc(
        rect,
        startAngle * (pi / 180),
        sweepAngle * (pi / 180),
        false,
        yellowOutlinePaint,
      );
    }
    canvas.drawArc(
      rect,
      startAngle * (pi / 180),
      sweepAngle * (pi / 180),
      false,
      paint,
    );
  }

  Color velocityToColor(double velocity) =>
      velToColor(velocity, simulationResult.maxTargetedVelocity);

  Offset vecToOffset(Vector2 vec) => Offset(vec.x, -vec.y);
}

Color velToColor(double velocity, double maxVelocity) {
  int r = ((1 - velocity / maxVelocity) * 255).round();
  int g = 255 - r;
  return Color.fromARGB(255, r, g, 0);
}
