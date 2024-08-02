import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/ir_read_painter.dart';
import 'package:robi_line_drawer/editor/painters/simulation_painter.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';

import 'abstract_painter.dart';

const Color white = Color(0xFFFFFFFF);

class LinePainter extends CustomPainter {
  final double scale;
  final RobiConfig robiConfig;
  final IrReadResult? irReadResult;
  final SimulationResult simulationResult;
  final IrReadPainterSettings irReadPainterSettings;
  final InstructionResult? highlightedInstruction;

  LinePainter({
    super.repaint,
    required this.scale,
    required this.robiConfig,
    this.irReadResult,
    required this.irReadPainterSettings,
    required this.simulationResult,
    required this.highlightedInstruction,
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final List<MyPainter> painters = [
      SimulationPainter(
        simulationResult: simulationResult,
        scale: scale,
        canvas: canvas,
        size: size,
        highlightedInstruction: highlightedInstruction
      ),
      if (irReadResult != null)
        IrReadPainter(
          robiConfig: robiConfig,
          scale: scale,
          irReadResult: irReadResult!,
          settings: irReadPainterSettings,
          canvas: canvas,
          size: size,
        )
    ];

    paintGrid(canvas, size);
    for (final painter in painters) {
      painter.paint();
    }
  }
}
