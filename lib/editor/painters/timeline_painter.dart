import 'package:flutter/material.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';

class TimelinePainter extends CustomPainter {
  final SimulationResult simResult;
  final InstructionResult? highlightedInstruction;
  static final Paint strokePaint = Paint()
    ..color = Colors.grey
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  static final Paint highlightPaint = Paint()
    ..color = Colors.orange
    ..style = PaintingStyle.fill;

  const TimelinePainter({
    required this.simResult,
    required this.highlightedInstruction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double t = 0;
    for (int i = 0; i < simResult.instructionResults.length; ++i) {
      InstructionResult result = simResult.instructionResults[i];

      t += result.outerTotalTime;
      final x = t / simResult.totalTime * size.width;

      if (result == highlightedInstruction) {
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            2,
            -result.outerTotalTime / simResult.totalTime * size.width,
            size.height - 4,
          ),
          highlightPaint,
        );
      }

      if (i == simResult.instructionResults.length - 1) {
        break;
      }

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        strokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
