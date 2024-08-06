import 'dart:math';

import 'package:curved_gradient/curved_gradient.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/abstract_painter.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../robi_api/robi_utils.dart';
import '../../robi_api/simulator.dart';
import 'line_painter.dart';

class SimulationPainter extends MyPainter {
  final SimulationResult simulationResult;
  final double scale;
  final Canvas canvas;
  final Size size;
  final double strokeWidth;
  final InstructionResult? highlightedInstruction;

  late final yellowOutlinePaint = Paint()
    ..color = Colors.yellow
    ..strokeWidth = (strokeWidth + 0.01) * scale
    ..style = PaintingStyle.stroke;

  SimulationPainter({
    required this.simulationResult,
    required this.scale,
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

    paintScale();
    paintVelocityScale();
  }

  void paintScale() {
    final Paint paint = Paint()
      ..strokeWidth = 1
      ..color = white;

    canvas.drawLine(Offset(size.width / 2 - 49, size.height - 20),
        Offset(size.width / 2 + 49, size.height - 20), paint);
    canvas.drawLine(Offset(size.width / 2 - 50, size.height - 25),
        Offset(size.width / 2 - 50, size.height - 15), paint);
    canvas.drawLine(Offset(size.width / 2 + 50, size.height - 25),
        Offset(size.width / 2 + 50, size.height - 15), paint);

    LinePainter.paintText("${(100.0 / scale).toStringAsFixed(2)}m",
        Offset(size.width / 2, size.height - 22), canvas, size);
  }

  void paintVelocityScale() {
    if (simulationResult.maxTargetedVelocity <= 0) return;

    List<Color> colors = [
      velocityToColor(0),
      velocityToColor(simulationResult.maxTargetedVelocity)
    ];

    final lineStart = Offset(size.width - 130, size.height - 20);
    final lineEnd = Offset(size.width - 30, size.height - 20);

    final accelerationPaint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        radius: 0.5 / sqrt2,
      ).createShader(
          Rect.fromCircle(center: lineStart, radius: lineEnd.dx - lineStart.dx))
      ..strokeWidth = 10;

    canvas.drawLine(lineStart, lineEnd, accelerationPaint);
    canvas.drawLine(
        lineStart.translate(-1, -5),
        lineStart.translate(-1, 5),
        Paint()
          ..color = white
          ..strokeWidth = 1);
    canvas.drawLine(
        lineEnd.translate(1, -5),
        lineEnd.translate(1, 5),
        Paint()
          ..color = white
          ..strokeWidth = 1);
    LinePainter.paintText("0m/s", lineStart.translate(0, -7), canvas, size);
    LinePainter.paintText(
        "${simulationResult.maxTargetedVelocity.toStringAsFixed(2)}m/s",
        lineEnd.translate(0, -7),
        canvas,
        size);
  }

  static Alignment polarToAlignment(double deg) => Alignment(cosD(deg), -sinD(deg));

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
          center: vecToOffset(instructionResult.startPosition, size),
          radius: instructionResult.startPosition
                  .distanceTo(instructionResult.accelerationEndPoint) *
              scale))
      ..strokeWidth = strokeWidth * scale;

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
          center: vecToOffset(instructionResult.decelerationStartPoint, size),
          radius: instructionResult.decelerationStartPoint
                  .distanceTo(instructionResult.endPosition) *
              scale))
      ..strokeWidth = strokeWidth * scale;

    if (instructionResult == highlightedInstruction) {
      canvas.drawLine(vecToOffset(instructionResult.startPosition, size),
          vecToOffset(instructionResult.endPosition, size), yellowOutlinePaint);
    }

    // Draw the original line
    canvas.drawLine(
      vecToOffset(instructionResult.startPosition, size),
      vecToOffset(instructionResult.accelerationEndPoint, size),
      accelerationPaint,
    );
    canvas.drawLine(
      vecToOffset(instructionResult.accelerationEndPoint, size),
      vecToOffset(instructionResult.decelerationStartPoint, size),
      Paint()
        ..color = velocityToColor(instructionResult.maxVelocity)
        ..strokeWidth = strokeWidth * scale,
    );
    canvas.drawLine(
      vecToOffset(instructionResult.decelerationStartPoint, size),
      vecToOffset(instructionResult.endPosition, size),
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

    final rect = Rect.fromCircle(
        center: vecToOffset(center, size), radius: radius * scale);

    double o = startAngle;

    if (left) {
      colors = colors.reversed.toList();
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * scale
      ..shader = SweepGradient(
        colors: colors,
        stops: [0, degree / 360],
        transform: GradientRotation(o * (pi / 180)),
      ).createShader(rect);

    if (degree >= 360) {
      if (highlight) {
        canvas.drawCircle(
            vecToOffset(center, size), radius * scale, yellowOutlinePaint);
      }
      canvas.drawCircle(vecToOffset(center, size), radius * scale, paint);
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

  Color velocityToColor(double velocity) {
    int r =
        ((1 - velocity / simulationResult.maxTargetedVelocity) * 255).round();
    int g = 255 - r;
    return Color.fromARGB(255, r, g, 0);
  }

  Offset vecToOffset(Vector2 vec, Size size) =>
      Offset(vec.x * scale, -vec.y * scale)
          .translate(size.width / 2, size.height / 2);
}
