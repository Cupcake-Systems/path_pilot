import 'package:flutter/material.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';

class TimelinePainter extends CustomPainter {
  final SimulationResult simResult;
  final InstructionResult? highlightedInstruction;
  static final Paint strokePaint = Paint()
    ..color = Colors.grey
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  static final Paint highlightPaint = Paint()
    ..color = Colors.orangeAccent
    ..style = PaintingStyle.fill;

  const TimelinePainter({
    required this.simResult,
    required this.highlightedInstruction,
  });

  static const double highlightOffset = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (simResult.instructionResults.isEmpty) return;

    final cornerRadius = Radius.circular(size.height / 2);
    double t = simResult.instructionResults.first.totalTime;
    double x = t / simResult.totalTime * size.width;

    for (int i = 1; i < simResult.instructionResults.length; ++i) {
      InstructionResult result = simResult.instructionResults[i];

      x = t / simResult.totalTime * size.width;

      if (result == highlightedInstruction && i != simResult.instructionResults.length - 1 && i > 0) {
        final width = result.totalTime / simResult.totalTime * size.width;
        canvas.drawRect(
          Rect.fromLTWH(x, highlightOffset, width, size.height - highlightOffset * 2),
          highlightPaint,
        );
      }

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        strokePaint,
      );

      t += result.totalTime;
    }

    if (highlightedInstruction == simResult.instructionResults.last) {
      if (simResult.instructionResults.length == 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, highlightOffset, size.width, size.height - highlightOffset * 2),
            cornerRadius,
          ),
          highlightPaint,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, highlightOffset, size.width - x, size.height - highlightOffset * 2),
            topRight: cornerRadius,
            bottomRight: cornerRadius,
          ),
          highlightPaint,
        );
      }
    } else if (highlightedInstruction == simResult.instructionResults.first) {
      final width = simResult.instructionResults.first.totalTime / simResult.totalTime * size.width;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            0,
            highlightOffset,
            width,
            size.height - highlightOffset * 2,
          ),
          topLeft: cornerRadius,
          bottomLeft: cornerRadius,
        ),
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(TimelinePainter oldDelegate) => false;
}
