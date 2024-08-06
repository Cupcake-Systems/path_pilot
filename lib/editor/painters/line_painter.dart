import 'dart:math';

import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/ir_read_painter.dart';
import 'package:robi_line_drawer/editor/painters/simulation_painter.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart';

import 'abstract_painter.dart';

const Color white = Color(0xFFFFFFFF);

class LinePainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final RobiConfig robiConfig;
  final SimulationResult simulationResult;
  final IrReadPainterSettings irReadPainterSettings;
  final InstructionResult? highlightedInstruction;
  final IrCalculatorResult? irCalculatorResult;
  final List<Vector2>? irPathApproximation;

  LinePainter({
    super.repaint,
    required this.scale,
    required this.robiConfig,
    required this.irReadPainterSettings,
    required this.simulationResult,
    required this.highlightedInstruction,
    this.irCalculatorResult,
    this.irPathApproximation,
    required this.offset,
  });

  static void paintText(String text, Offset offset, Canvas canvas, Size size) {
    final textSpan = TextSpan(text: text);
    final textPainter =
        TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout(minWidth: 0, maxWidth: size.width);
    textPainter.paint(
        canvas,
        Offset(
            offset.dx - textPainter.width / 2, offset.dy - textPainter.height));
  }

  void paintGrid(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 1
      ..color = white.withAlpha(100);

    final int xLineCount = size.width ~/ scale + 1;
    final int yLineCount = size.height ~/ scale + 1;

    for (double i = offset.dx - scale * xLineCount;
        i < xLineCount * scale;
        i += scale) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = offset.dx + 0.5 * scale - scale * xLineCount;
        i < xLineCount * scale;
        i += scale) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height),
          paint..color = white.withAlpha(50));
    }

    for (double i = offset.dy - scale * yLineCount;
        i < yLineCount * scale;
        i += scale) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    for (double i = offset.dy + 0.5 * scale - scale * yLineCount;
        i < yLineCount * scale;
        i += scale) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    canvas.drawLine(Offset(0, offset.dy), Offset(size.width, offset.dy), paint);
    canvas.drawLine(
        Offset(offset.dx, 0), Offset(offset.dx, size.height), paint);
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

    LinePainter.paintText("${(100.0 / scale).toStringAsFixed(2)}m",
        Offset(size.width / 2, size.height - 22), canvas, size);
  }

  void paintVelocityScale(Canvas canvas, Size size) {
    if (simulationResult.maxTargetedVelocity <= 0) return;

    List<Color> colors = [
      velToColor(0, simulationResult.maxTargetedVelocity),
      velToColor(simulationResult.maxTargetedVelocity,
          simulationResult.maxTargetedVelocity)
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    paintGrid(canvas, size);
    paintScale(canvas, size);
    paintVelocityScale(canvas, size);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    if (irCalculatorResult != null) assert(irPathApproximation != null);
    final List<MyPainter> painters = [
      SimulationPainter(
        simulationResult: simulationResult,
        canvas: canvas,
        size: size,
        highlightedInstruction: highlightedInstruction,
      ),
      if (irCalculatorResult != null)
        IrReadPainter(
          robiConfig: robiConfig,
          settings: irReadPainterSettings,
          canvas: canvas,
          size: size,
          irCalculatorResult: irCalculatorResult!,
          pathApproximation: irPathApproximation!,
        )
    ];

    for (final painter in painters) {
      painter.paint();
    }

    canvas.restore();
  }
}
