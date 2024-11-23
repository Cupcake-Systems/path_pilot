import 'package:flutter/material.dart';

class IrReadTimelinePainter extends CustomPainter {
  final double totalTime, measurementsTimeDelta;

  const IrReadTimelinePainter({
    super.repaint,
    required this.totalTime,
    required this.measurementsTimeDelta,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double t = measurementsTimeDelta;
    double x = t / totalTime * size.width;

    if (x < 3) return;

    while (t < totalTime) {
      x = t / totalTime * size.width;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );

      t += measurementsTimeDelta;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
