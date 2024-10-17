import 'dart:math';

import 'package:curved_gradient/curved_gradient.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/abstract_painter.dart';
import 'package:vector_math/vector_math.dart' show Vector2, radians;

import '../../robi_api/robi_utils.dart';
import '../../robi_api/simulator.dart';

class SimulationPainter extends MyPainter {
  final SimulationResult simulationResult;
  final Canvas canvas;
  final Size size;
  final double strokeWidth;
  final InstructionResult? highlightedInstruction;

  late final highlightPaint = Paint()
    ..color = Colors.orangeAccent
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
      } else if (result is RapidTurnResult) {
      } else {
        throw UnsupportedError("");
      }
    }
  }

  static Alignment polarToAlignment(double deg) => Alignment(cosD(deg), -sinD(deg));

  void drawDrive(DriveResult instructionResult) {
    final accelerationEndPoint = polarToCartesian(instructionResult.startRotation, instructionResult.accelerationDistance) + instructionResult.startPosition;
    final decelerationStartPoint = instructionResult.endPosition + polarToCartesian(instructionResult.endRotation - 180, instructionResult.decelerationDistance);

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
      ).createShader(Rect.fromCircle(center: vecToOffset(instructionResult.startPosition), radius: instructionResult.accelerationDistance))
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
      ).createShader(Rect.fromCircle(center: vecToOffset(decelerationStartPoint), radius: instructionResult.decelerationDistance))
      ..strokeWidth = strokeWidth;

    if (instructionResult == highlightedInstruction) {
      canvas.drawLine(vecToOffset(instructionResult.startPosition), vecToOffset(instructionResult.endPosition), highlightPaint);
    }

    // Draw the original line
    canvas.drawLine(
      vecToOffset(instructionResult.startPosition),
      vecToOffset(accelerationEndPoint),
      accelerationPaint,
    );
    canvas.drawLine(
      vecToOffset(accelerationEndPoint),
      vecToOffset(decelerationStartPoint),
      Paint()
        ..color = velocityToColor(instructionResult.maxVelocity)
        ..strokeWidth = strokeWidth,
    );
    canvas.drawLine(
      vecToOffset(decelerationStartPoint),
      vecToOffset(instructionResult.endPosition),
      decelerationPaint,
    );
  }

  void drawTurn(TurnResult instruction) {
    final highlight = instruction == highlightedInstruction;
    final radius = (instruction.innerRadius + instruction.outerRadius) / 2;

    drawCirclePart(
      radius: radius,
      left: instruction.left,
      lineStart: vecToOffset(instruction.startPosition),
      sweepAngle: instruction.accelerationDegree,
      robiRotation: instruction.startRotation,
      highlight: highlight,
      degreeOffset: 0,
      initialVelocity: instruction.outerInitialVelocity,
      endVelocity: instruction.maxOuterVelocity,
    );

    drawCirclePart(
      radius: radius,
      left: instruction.left,
      lineStart: vecToOffset(instruction.startPosition),
      sweepAngle: instruction.totalTurnDegree - instruction.accelerationDegree - instruction.decelerationDegree,
      robiRotation: instruction.startRotation,
      highlight: highlight,
      degreeOffset: instruction.accelerationDegree,
      initialVelocity: instruction.maxOuterVelocity,
      endVelocity: instruction.maxOuterVelocity,
    );

    drawCirclePart(
      radius: radius,
      left: instruction.left,
      lineStart: vecToOffset(instruction.startPosition),
      sweepAngle: instruction.decelerationDegree,
      robiRotation: instruction.startRotation,
      highlight: highlight,
      degreeOffset: instruction.totalTurnDegree - instruction.decelerationDegree,
      initialVelocity: instruction.maxOuterVelocity,
      endVelocity: instruction.finalInnerVelocity,
    );
  }

  void drawCirclePart({
    required double radius,
    required bool left,
    required Offset lineStart,
    required double sweepAngle,
    required double robiRotation,
    required bool highlight,
    required double degreeOffset,
    required double initialVelocity,
    required double endVelocity,
  }) {
    double startAngle = 90 - sweepAngle - robiRotation;
    Offset center = vecToOffset(polarToCartesian(robiRotation + 90, radius));

    if (!left) {
      startAngle = -90 - robiRotation;
      degreeOffset = -degreeOffset;
      center = vecToOffset(polarToCartesian(startAngle, radius));
      center = center.scale(-1, 1);
    }

    final rect = Rect.fromCircle(center: lineStart + center, radius: radius);

    List<Color> colors = [
      velocityToColor(initialVelocity),
      velocityToColor(endVelocity),
    ];
    if (left) colors = colors.reversed.toList();

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        colors: colors,
        stops: [0, sweepAngle / 360],
        transform: GradientRotation(radians(startAngle - degreeOffset)),
      ).createShader(rect);

    if (highlight) {
      canvas.drawArc(
        rect,
        radians(startAngle - degreeOffset),
        radians(sweepAngle),
        false,
        highlightPaint,
      );
    }

    canvas.drawArc(
      Rect.fromCircle(center: lineStart + center, radius: radius),
      radians(startAngle - degreeOffset),
      radians(sweepAngle),
      false,
      paint,
    );
  }

  Color velocityToColor(double velocity) => velToColor(velocity, simulationResult.maxTargetedVelocity);

  Offset vecToOffset(Vector2 vec) => Offset(vec.x, -vec.y);
}

Color velToColor(double velocity, double maxVelocity) {
  int r = ((1 - velocity / maxVelocity) * 255).round();
  int g = 255 - r;
  return Color.fromARGB(255, r, g, 0);
}

Vector2 centerOfCircle(double radius, double angle, bool left) {
  Vector2 center = polarToCartesian(angle + 90, radius);

  if (!left) {
    center = polarToCartesian(-90 - angle, radius);
    center = Vector2(-center.x, center.y);
  }

  return center;
}
