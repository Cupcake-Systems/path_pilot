import 'dart:math';

import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/abstract_painter.dart';
import 'package:robi_line_drawer/editor/painters/timeline_painter.dart';
import 'package:vector_math/vector_math.dart' show Aabb2, Vector2, radians;

import '../../helper/curved_gradient.dart';
import '../../helper/geometry.dart';
import '../../robi_api/robi_utils.dart';

class SimulationPainter extends MyPainter {
  final SimulationResult simulationResult;
  final Canvas canvas;
  final Aabb2 visibleArea;
  final double strokeWidth;
  final InstructionResult? highlightedInstruction;

  static final Color zeroVelColor = velToColor(0, 1);
  static final Paint zeroVelPaint = Paint()..color = zeroVelColor;

  late final highlightPaint = Paint()
    ..color = TimelinePainter.highlightPaint.color
    ..strokeWidth = (strokeWidth + 0.01)
    ..style = PaintingStyle.stroke;
  late final Vector2 visionCenter = visibleArea.center;
  late final Vector2 expansion = Vector2.all(strokeWidth / 2);
  late final Aabb2 expandedArea = Aabb2.minMax(
    visibleArea.min - expansion,
    visibleArea.max + expansion,
  );
  late final double centerMaxDistance = visionCenter.distanceTo(expandedArea.max);

  static const int curveGranularity = 10;

  SimulationPainter({
    required this.simulationResult,
    required this.canvas,
    required this.visibleArea,
    this.strokeWidth = 0.02,
    required this.highlightedInstruction,
  });

  @override
  void paint() {
    for (int i = 0; i < simulationResult.rapidTurnResults.length; ++i) {
      final result = simulationResult.rapidTurnResults[i];
      if (result.intersectsWithAabb(expandedArea)) {
        drawRapidTurn(result);
      }
    }

    for (int i = 0; i < simulationResult.driveResults.length; ++i) {
      final result = simulationResult.driveResults[i];
      if (result.isVisibleFast(visionCenter, centerMaxDistance)) {
        drawDrive(result);
      }
    }

    for (int i = 0; i < simulationResult.turnResults.length; ++i) {
      final result = simulationResult.turnResults[i];
      if (result.isVisibleFast(visionCenter, centerMaxDistance)) {
        drawTurn(result);
      }
    }
  }

  void drawDrive(final DriveResult instructionResult) => drawDriveWO(
        instructionResult,
        vecToOffset(instructionResult.startPosition),
        vecToOffset(instructionResult.endPosition),
      );

  void drawDriveWO(final DriveResult instructionResult, final Offset startPositionOffset, final Offset endPositionOffset) {
    final accelerationEndPoint = polarToCartesian(instructionResult.startRotation, instructionResult.accelerationDistance) + instructionResult.startPosition;
    final decelerationStartPoint = instructionResult.endPosition + polarToCartesian(instructionResult.endRotation - 180, instructionResult.decelerationDistance);
    final maxVelColor = velocityToColor(instructionResult.maxVelocity);
    final startRotationAlignment = polarToAlignment(instructionResult.startRotation);
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
    final center = vecToOffset(instruction.center);

    if (instruction == highlightedInstruction) {
      drawCirclePart(
        radius: instruction.medianRadius,
        left: instruction.left,
        lineStart: startPositionOffset,
        sweepAngle: instruction.totalTurnDegree,
        robiRotation: instruction.startRotation,
        paint: highlightPaint,
        center: center,
      );
    }

    drawCirclePart(
      radius: instruction.medianRadius,
      left: instruction.left,
      lineStart: startPositionOffset,
      sweepAngle: instruction.accelerationDegree,
      robiRotation: instruction.startRotation,
      initialVelocity: instruction.outerInitialVelocity,
      endVelocity: instruction.maxOuterVelocity,
      center: center,
    );

    drawCirclePart(
      radius: instruction.medianRadius,
      left: instruction.left,
      lineStart: startPositionOffset,
      sweepAngle: instruction.totalTurnDegree - instruction.accelerationDegree - instruction.decelerationDegree,
      robiRotation: instruction.startRotation,
      degreeOffset: instruction.accelerationDegree,
      initialVelocity: instruction.maxOuterVelocity,
      endVelocity: instruction.maxOuterVelocity,
      center: center,
    );

    drawCirclePart(
      radius: instruction.medianRadius,
      left: instruction.left,
      lineStart: startPositionOffset,
      sweepAngle: instruction.decelerationDegree,
      robiRotation: instruction.startRotation,
      degreeOffset: instruction.totalTurnDegree - instruction.decelerationDegree,
      initialVelocity: instruction.maxOuterVelocity,
      endVelocity: instruction.finalInnerVelocity,
      center: center,
    );
  }

  void drawCirclePart({
    required final double radius,
    required final bool left,
    required final Offset lineStart,
    required final double sweepAngle,
    required final double robiRotation,
    required final Offset center,
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

    if (!left) {
      startAngle = -90 - robiRotation;
      degreeOffset = -degreeOffset;
    }

    if (paint == null) {
      List<Color> colors = [
        velocityToColor(initialVelocity!),
        velocityToColor(endVelocity!),
      ];

      if (left) colors = colors.reversed.toList();

      final rect = Rect.fromCircle(center: center, radius: radius);

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
      Rect.fromCircle(center: center, radius: radius),
      radians(startAngle - degreeOffset),
      radians(sweepAngle),
      false,
      paint,
    );
  }

  Color velocityToColor(final double velocity) => velToColor(velocity, simulationResult.maxTargetedVelocity);
}

Color velToColor(final double velocity, final double maxVelocity) {
  int r = ((1 - velocity / maxVelocity) * 255).round();
  int g = 255 - r;
  return Color.fromARGB(255, r, g, 0);
}
