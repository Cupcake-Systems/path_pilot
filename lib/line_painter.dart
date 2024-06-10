import 'dart:math';

import 'package:flutter/material.dart';
import 'package:robi_line_drawer/robi_path_serializer.dart';
import 'package:robi_line_drawer/robi_utils.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

class LinePainter extends CustomPainter {
  final SimulationResult simulationResult;
  final double scale;
  late final double strokeWidth;

  static const Color white = Color(0xFFFFFFFF);

  LinePainter(this.scale, this.simulationResult) {
    strokeWidth = 5 * (scale.toDouble() / 100);
  }

  void paintGrid(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 1
      ..color = white.withAlpha(100);

    for (double x = size.width / 2 % scale; x <= size.width; x += scale) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = size.height / 2 % scale; y <= size.height; y += scale) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    paint
      ..strokeWidth = 0.5
      ..color = white.withAlpha(50);

    for (double x = scale / 2 + size.width / 2 % scale;
        x <= size.width;
        x += scale) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = scale / 2 + size.height / 2 % scale;
        y <= size.height;
        y += scale) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void paintScale(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 1
      ..color = white;

    canvas.drawLine(Offset(size.width / 2 - 49, size.height - 20),
        Offset(size.width / 2 + 49, size.height - 20), paint);
    canvas.drawLine(Offset(size.width / 2 - 50, size.height - 25),
        Offset(size.width / 2 - 50, size.height - 15), paint);
    canvas.drawLine(Offset(size.width / 2 + 50, size.height - 25),
        Offset(size.width / 2 + 50, size.height - 15), paint);

    paintText("${(100.0 / scale).toStringAsFixed(2)}m",
        Offset(size.width / 2, size.height - 22), canvas, size);
  }

  void paintText(String text, Offset offset, Canvas canvas, Size size) {
    final textSpan = TextSpan(text: text);
    final textPainter =
        TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout(minWidth: 0, maxWidth: size.width);
    textPainter.paint(
        canvas,
        Offset(
            offset.dx - textPainter.width / 2, offset.dy - textPainter.height));
  }

  void paintVelocityScale(Canvas canvas, Size size) {
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
    paintText("0m/s", lineStart.translate(0, -7), canvas, size);
    paintText("${simulationResult.maxTargetedVelocity.toStringAsFixed(2)}m/s",
        lineEnd.translate(0, -7), canvas, size);
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintGrid(canvas, size);

    InstructionResult prevResult = startResult;

    for (InstructionResult result in simulationResult.instructionResults) {
      if (result is DriveResult) {
        drawDrive(prevResult, result, canvas, size);
      } else if (result is TurnResult) {
        drawTurn(prevResult, result, canvas, size);
      }

      prevResult = result;
    }

    paintScale(canvas, size);
    paintVelocityScale(canvas, size);
  }

  void drawDrive(InstructionResult prevInstructionResult,
      DriveResult instructionResult, Canvas canvas, Size size) {
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
          center: vecToOffset(prevInstructionResult.endPosition, size),
          radius: instructionResult.accelerationDistance * scale))
      ..strokeWidth = strokeWidth;

    canvas.drawLine(vecToOffset(prevInstructionResult.endPosition, size),
        vecToOffset(instructionResult.endPosition, size), accelerationPaint);
  }

  void drawTurn(InstructionResult prevInstructionResult, TurnResult instruction,
      Canvas canvas, Size size) {
    if (prevInstructionResult.endPosition == instruction.endPosition) {
      return;
    }

    final degree =
        (prevInstructionResult.endRotation - instruction.endRotation).abs();
    final left = prevInstructionResult.endRotation < instruction.endRotation;

    List<Color> colors = [
      velocityToColor(prevInstructionResult.managedVelocity),
      velocityToColor(instruction.managedVelocity)
    ];

    drawCirclePart(
        instruction.turnRadius,
        degree,
        prevInstructionResult.endRotation,
        prevInstructionResult.endPosition,
        left,
        canvas,
        size,
        colors);
  }

  void drawCirclePart(double radius, double degree, double rotation,
      Vector2 offset, bool left, Canvas canvas, Size size, List<Color> colors) {
    double startAngle = 270 - rotation;
    double sweepAngle = degree % 360;

    Vector2 center = polarToCartesian(rotation + 90, radius);

    if (left) {
      startAngle -= 180 + degree;
      center.y *= -1;
    } else {
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
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        colors: colors,
        stops: [0, degree / 360],
        transform: GradientRotation(o * (pi / 180)),
      ).createShader(rect);

    if (degree >= 360) {
      canvas.drawCircle(vecToOffset(center, size), radius * scale, paint);
    }

    canvas.drawArc(
      rect,
      startAngle * (pi / 180),
      sweepAngle * (pi / 180),
      false,
      paint,
    );

    //canvas.drawCircle(vecToOffset(center, size), scale * radius, paint);
  }

  Color velocityToColor(double velocity) {
    int r =
        ((1 - velocity / simulationResult.maxTargetedVelocity) * 255).round();
    int g = 255 - r;
    return Color.fromARGB(255, r, g, 0);
  }

  Offset vecToOffset(Vector2 vec, Size size) =>
      Offset(vec.x * scale, vec.y * scale)
          .translate(size.width / 2, size.height / 2);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
