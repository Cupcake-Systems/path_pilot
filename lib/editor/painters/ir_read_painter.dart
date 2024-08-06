import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/abstract_painter.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../robi_api/ir_read_api.dart';
import '../../robi_api/robi_utils.dart';
import 'line_painter.dart';

class IrReadPainterSettings {
  bool showTracks, showCalculatedPath;
  int irReadingsThreshold;

  IrReadPainterSettings({
    required this.irReadingsThreshold,
    required this.showCalculatedPath,
    required this.showTracks,
  });
}

class IrReadPainter extends MyPainter {
  final RobiConfig robiConfig;
  final double scale;
  final IrReadPainterSettings settings;
  final Canvas canvas;
  final Size size;
  final IrCalculatorResult irCalculatorResult;
  final List<Vector2> pathApproximation;

  late final Paint leftTrackPaint = Paint()
    ..strokeWidth = robiConfig.wheelWidth * scale
    ..color = white.withOpacity(0.6)
    ..style = PaintingStyle.stroke;
  late final Paint rightTrackPaint = Paint()
    ..strokeWidth = robiConfig.wheelWidth * scale
    ..color = white.withOpacity(0.6)
    ..style = PaintingStyle.stroke;
  late final middle = Offset(size.width / 2, size.height / 2);

  IrReadPainter({
    required this.robiConfig,
    required this.scale,
    required this.settings,
    required this.canvas,
    required this.size,
    required this.irCalculatorResult,
    required this.pathApproximation,
  });

  void addLine(Vector2 a, Path path) {
    path.lineTo(a.x * scale + middle.dx, a.y * scale + middle.dy);
  }

  void drawCircle(Vector2 a, Paint paint, {double radius = 0.005}) {
    final o = Offset(a.x, a.y);
    canvas.drawCircle(o * scale + middle, radius * scale, paint);
  }

  @override
  void paint() {
    Path leftPath = Path();
    Path rightPath = Path();

    Vector2 first = irCalculatorResult.irData.first.$2.position;

    leftPath.moveTo(first.x * scale + middle.dx, first.y * scale + middle.dy);
    rightPath.moveTo(first.x * scale + middle.dx, first.y * scale + middle.dy);

    for (int i = 0; i < irCalculatorResult.wheelPositions.length; ++i) {
      final wheelPositions = irCalculatorResult.wheelPositions[i];
      final irPositions = irCalculatorResult.irData[i];

      if (settings.showTracks) {
        addLine(wheelPositions.$1, leftPath);
        addLine(wheelPositions.$2, rightPath);
      }

      for (final ir in [irPositions.$1, irPositions.$2, irPositions.$3]) {
        if (ir.value < settings.irReadingsThreshold) {
          drawCircle(ir.position, irToPaint(ir.value));
        }
      }
    }

    if (settings.showTracks) {
      canvas.drawPath(rightPath, rightTrackPaint);
      canvas.drawPath(leftPath, leftTrackPaint);
    }

    if (settings.showCalculatedPath) paintReducedLineEstimate();
  }

  Paint irToPaint(int rawIr) {
    int gray = rawIr ~/ 4;

    if (gray > 255) {
      gray = 255;
    }

    return Paint()..color = Color.fromARGB(255, gray, gray, gray);
  }

  void paintReducedLineEstimate() {
    final path = Path();
    path.moveTo(middle.dx, middle.dy);

    for (final point in pathApproximation) {
      drawCircle(point, Paint()..color = Colors.white);
      addLine(point, path);
    }

    canvas.drawPath(
        path,
        Paint()
          ..strokeWidth = 0.005 * scale
          ..color = Colors.blue
          ..style = PaintingStyle.stroke);
  }
}
