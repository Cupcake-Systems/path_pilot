import 'dart:math';

import 'package:flutter/material.dart';
import 'package:robi_line_drawer/robi_utils.dart';
import 'package:vector_math/vector_math.dart';

class LinePainter extends CustomPainter {
  late SimulationResult simulationResult;
  final double scale;
  final RobiConfig robiConfig;
  late final double strokeWidth;
  late final Simulator simulater;

  static const Color white = Color(0xFFFFFFFF);

  LinePainter(
      List<MissionInstruction> instructions, this.scale, this.robiConfig) {
    simulater = Simulator(robiConfig);
    simulationResult = simulater.calculate(instructions);
    strokeWidth = 5 * (scale.toDouble() / 100);
  }

  void paintGrid(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 1
      ..color = const Color.fromARGB(100, 255, 255, 255);

    for (double x = 0; x <= size.width; x += scale) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += scale) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    paint
      ..strokeWidth = 0.5
      ..color = const Color.fromARGB(50, 255, 255, 255);

    for (double x = scale / 2; x <= size.width; x += scale) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = scale / 2; y <= size.height; y += scale) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void paintScale(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 1
      ..color = white;

    canvas.drawLine(
        Offset(1, size.height - 20), Offset(99, size.height - 20), paint);
    canvas.drawLine(
        Offset(100, size.height - 25), Offset(100, size.height - 15), paint);
    canvas.drawLine(
        Offset(0, size.height - 25), Offset(0, size.height - 15), paint);

    paintText("${(100.0 / scale).toStringAsFixed(2)}m",
        Offset(30, size.height - 20), canvas, size);
  }

  void paintText(String text, Offset offset, Canvas canvas, Size size) {
    final textSpan = TextSpan(text: text);
    final textPainter =
        TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout(minWidth: 0, maxWidth: size.width);
    textPainter.paint(
        canvas, Offset(offset.dx, offset.dy - textPainter.height));
  }

  void paintVelocityScale(Canvas canvas, Size size) {
    if (simulationResult.maxTargetedVelocity <= 0) return;

    List<Color> colors = [
      velocityToColor(0),
      velocityToColor(simulationResult.maxTargetedVelocity)
    ];

    final lineStart = Offset(size.width - 120, size.height - 20);
    final lineEnd = Offset(size.width - 20, size.height - 20);

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
    paintText("0m/s", lineStart.translate(-15, -7), canvas, size);
    paintText("${simulationResult.maxTargetedVelocity}m/s",
        lineEnd.translate(-20, -7), canvas, size);
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintGrid(canvas, size);
    paintScale(canvas, size);
    paintVelocityScale(canvas, size);

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
    if (prevInstructionResult.endPosition == instructionResult.endPosition) {
      return;
    }

    List<Color> colors = [
      velocityToColor(prevInstructionResult.managedVelocity),
      velocityToColor(instructionResult.managedVelocity)
    ];

    final accelerationPaint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        radius: 0.5 / sqrt2,
      ).createShader(Rect.fromCircle(
          center: vecToOffset(prevInstructionResult.endPosition),
          radius: instructionResult.accelerationDistance * scale))
      ..strokeWidth = strokeWidth;

    canvas.drawLine(vecToOffset(prevInstructionResult.endPosition),
        vecToOffset(instructionResult.endPosition), accelerationPaint);
  }

  void drawTurn(InstructionResult prevInstructionResult, TurnResult instruction,
      Canvas canvas) {
    if (prevInstructionResult.endPosition == instruction.endPosition) {
      return;
    }

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

  Path drawCirclePart(double radius, double degree, double rotation,
      Vector2 offset, bool left) {
    double startAngle = 270 - rotation;
    double sweepAngle = degree;

    Vector2 center = polarToCartesian(rotation + 90, radius);

    if (left) {
      startAngle -= 180 + degree;
      center.y *= -1;
    } else {
      center.x *= -1;
    }

    center += offset;

    return Path()
      ..arcTo(
          Rect.fromCircle(center: vecToOffset(center), radius: radius * scale),
          startAngle * (pi / 180),
          sweepAngle * (pi / 180),
          false);
  }

  Color velocityToColor(double velocity) {
    int r =
        ((1 - velocity / simulationResult.maxTargetedVelocity) * 255).round();
    int g = 255 - r;
    return Color.fromARGB(255, r, g, 0);
  }

  Offset vecToOffset(Vector2 vec) => Offset(vec.x * scale, vec.y * scale);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
