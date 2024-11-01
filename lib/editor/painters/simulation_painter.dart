import 'dart:math';

import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/abstract_painter.dart';
import 'package:robi_line_drawer/editor/painters/timeline_painter.dart';
import 'package:vector_math/vector_math.dart' show Vector2, radians;

import '../../helper/curved_gradient.dart';
import '../../robi_api/robi_utils.dart';
import '../../robi_api/simulator.dart';

class SimulationPainter extends MyPainter {
  final SimulationResult simulationResult;
  final Canvas canvas;
  final Size size;
  final double strokeWidth;
  final InstructionResult? highlightedInstruction;

  late final highlightPaint = Paint()
    ..color = TimelinePainter.highlightPaint.color
    ..strokeWidth = (strokeWidth + 0.01)
    ..style = PaintingStyle.stroke;

  late final Color zeroVelColor = velocityToColor(0);
  late final Paint zeroVelPaint = Paint()..color = zeroVelColor;

  static const int curveGranularity = 10;

  SimulationPainter({
    required this.simulationResult,
    required this.canvas,
    required this.size,
    this.strokeWidth = 0.02,
    required this.highlightedInstruction,
  });

  @override
  void paint() {
    for (final result in simulationResult.rapidTurnResults) {
      drawRapidTurn(result);
    }

    Offset o = Offset.zero;
    for (final result in simulationResult.instructionResults) {
      if (result is DriveResult) {
        o = drawDriveWO(result, o);
      } else if (result is TurnResult) {
        drawTurnWO(result, o);
        o = vecToOffset(result.endPosition);
      } else if (result is RapidTurnResult) {
      } else {
        throw UnsupportedError("");
      }
    }
  }

  static Alignment polarToAlignment(final double deg) => Alignment(cosD(deg), -sinD(deg));

  void drawDrive(final DriveResult instructionResult) => drawDriveWO(
        instructionResult,
        vecToOffset(instructionResult.startPosition),
      );

  Offset drawDriveWO(final DriveResult instructionResult, final Offset startPositionOffset) {
    final accelerationEndPoint = polarToCartesian(instructionResult.startRotation, instructionResult.accelerationDistance) + instructionResult.startPosition;
    final decelerationStartPoint = instructionResult.endPosition + polarToCartesian(instructionResult.endRotation - 180, instructionResult.decelerationDistance);
    final maxVelColor = velocityToColor(instructionResult.maxVelocity);
    final startRotationAlignment = polarToAlignment(instructionResult.startRotation);
    final endPositionOffset = vecToOffset(instructionResult.endPosition);
    final decelerationStartOffset = vecToOffset(decelerationStartPoint);

    final accelerationPaint = Paint()
      ..shader = CurvedGradient(
        colors: (
          velocityToColor(instructionResult.initialVelocity),
          maxVelColor,
        ),
        begin: Alignment.center,
        end: startRotationAlignment,
        granularity: curveGranularity,
        curveGenerator: (x) => sqrt(x),
      ).createShader(Rect.fromCircle(
        center: startPositionOffset,
        radius: instructionResult.accelerationDistance,
      ))
      ..strokeWidth = strokeWidth;

    final decelerationPaint = Paint()
      ..shader = CurvedGradient(
        colors: (
          velocityToColor(instructionResult.finalVelocity),
          maxVelColor,
        ),
        begin: Alignment.center,
        end: startRotationAlignment,
        granularity: curveGranularity,
        curveGenerator: (x) => sqrt(1 - x),
      ).createShader(
        Rect.fromCircle(
          center: decelerationStartOffset,
          radius: instructionResult.decelerationDistance,
        ),
      )
      ..strokeWidth = strokeWidth;

    if (instructionResult == highlightedInstruction) {
      canvas.drawLine(
        startPositionOffset,
        endPositionOffset,
        highlightPaint,
      );
    }

    // Draw the original line
    canvas.drawLine(
      startPositionOffset,
      vecToOffset(accelerationEndPoint),
      accelerationPaint,
    );
    canvas.drawLine(
      vecToOffset(accelerationEndPoint),
      decelerationStartOffset,
      Paint()
        ..color = maxVelColor
        ..strokeWidth = strokeWidth,
    );
    canvas.drawLine(
      decelerationStartOffset,
      endPositionOffset,
      decelerationPaint,
    );

    return endPositionOffset;
  }

  void drawRapidTurn(final RapidTurnResult res) => drawRapidTurnWO(res, vecToOffset(res.startPosition));

  void drawRapidTurnWO(final RapidTurnResult res, final Offset offset) {
    if (res == highlightedInstruction) {
      canvas.drawCircle(
        offset,
        strokeWidth / 2,
        highlightPaint..strokeWidth = strokeWidth / 2,
      );
    }

    canvas.drawCircle(
      offset,
      strokeWidth / 2,
      zeroVelPaint,
    );
  }

  void drawTurn(final TurnResult instruction) => drawTurnWO(
        instruction,
        vecToOffset(instruction.startPosition),
      );

  void drawTurnWO(final TurnResult instruction, final Offset startPositionOffset) {
    final radius = (instruction.innerRadius + instruction.outerRadius) / 2;

    if (instruction == highlightedInstruction) {
      drawCirclePart(
        radius: radius,
        left: instruction.left,
        lineStart: startPositionOffset,
        sweepAngle: instruction.totalTurnDegree,
        robiRotation: instruction.startRotation,
        paint: highlightPaint,
      );
    }

    drawCirclePart(
      radius: radius,
      left: instruction.left,
      lineStart: startPositionOffset,
      sweepAngle: instruction.accelerationDegree,
      robiRotation: instruction.startRotation,
      initialVelocity: instruction.outerInitialVelocity,
      endVelocity: instruction.maxOuterVelocity,
    );

    drawCirclePart(
      radius: radius,
      left: instruction.left,
      lineStart: startPositionOffset,
      sweepAngle: instruction.totalTurnDegree - instruction.accelerationDegree - instruction.decelerationDegree,
      robiRotation: instruction.startRotation,
      degreeOffset: instruction.accelerationDegree,
      initialVelocity: instruction.maxOuterVelocity,
      endVelocity: instruction.maxOuterVelocity,
    );

    drawCirclePart(
      radius: radius,
      left: instruction.left,
      lineStart: startPositionOffset,
      sweepAngle: instruction.decelerationDegree,
      robiRotation: instruction.startRotation,
      degreeOffset: instruction.totalTurnDegree - instruction.decelerationDegree,
      initialVelocity: instruction.maxOuterVelocity,
      endVelocity: instruction.finalInnerVelocity,
    );
  }

  void drawCirclePart({
    required final double radius,
    required final bool left,
    required final Offset lineStart,
    required final double sweepAngle,
    required final double robiRotation,
    double degreeOffset = 0,
    final double? initialVelocity,
    final double? endVelocity,
    Paint? paint,
  }) {
    assert(() {
      if (paint != null) return true;
      return initialVelocity != null && endVelocity != null;
    }());

    double startAngle = 90 - sweepAngle - robiRotation;
    Offset center = vecToOffset(polarToCartesian(robiRotation + 90, radius));

    if (!left) {
      startAngle = -90 - robiRotation;
      degreeOffset = -degreeOffset;
      center = vecToOffset(polarToCartesian(startAngle, radius));
      center = center.scale(-1, 1);
    }

    if (paint == null) {
      List<Color> colors = [
        velocityToColor(initialVelocity!),
        velocityToColor(endVelocity!),
      ];

      if (left) colors = colors.reversed.toList();

      final rect = Rect.fromCircle(center: lineStart + center, radius: radius);

      paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..shader = SweepGradient(
          colors: colors,
          stops: [0, sweepAngle / 360],
          transform: GradientRotation(radians(startAngle - degreeOffset)),
        ).createShader(rect);
    }

    canvas.drawArc(
      Rect.fromCircle(center: lineStart + center, radius: radius),
      radians(startAngle - degreeOffset),
      radians(sweepAngle),
      false,
      paint,
    );
  }

  Color velocityToColor(final double velocity) => velToColor(velocity, simulationResult.maxTargetedVelocity);
}

Offset vecToOffset(final Vector2 vec) => Offset(vec.x, -vec.y);

Color velToColor(final double velocity, final double maxVelocity) {
  int r = ((1 - velocity / maxVelocity) * 255).round();
  int g = 255 - r;
  return Color.fromARGB(255, r, g, 0);
}

Vector2 centerOfCircle(final double radius, final double angle, final bool left) {
  Vector2 center = polarToCartesian(angle + 90, radius);

  if (!left) {
    center = polarToCartesian(-90 - angle, radius);
    center = Vector2(-center.x, center.y);
  }

  return center;
}
