import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_pilot/editor/painters/abstract_painter.dart';
import 'package:vector_math/vector_math.dart' show Aabb2, Vector2;

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
  final IrReadPainterSettings settings;
  final Canvas canvas;
  final Size size;
  final IrCalculatorResult irCalculatorResult;
  final List<Vector2>? pathApproximation;

  late final Paint leftTrackPaint = Paint()
    ..strokeWidth = robiConfig.wheelWidth
    ..color = white.withOpacity(0.6)
    ..style = PaintingStyle.stroke;
  late final Paint rightTrackPaint = Paint()
    ..strokeWidth = robiConfig.wheelWidth
    ..color = white.withOpacity(0.6)
    ..style = PaintingStyle.stroke;

  final Aabb2 visibleArea;
  final Vector2 expansion = Vector2.all(irReadingsRadius);
  late final Aabb2 expandedArea = Aabb2.minMax(
    visibleArea.min - expansion,
    visibleArea.max + expansion,
  );
  late final Vector2 visionCenter = visibleArea.center;
  late final double centerMaxDistance = visionCenter.distanceTo(expandedArea.max);
  late final a = pow(centerMaxDistance + robiConfig.irDistance * 1.5, 2);

  static const double irReadingsRadius = 0.005;
  static Paint paintCache = Paint();

  IrReadPainter({
    required this.robiConfig,
    required this.settings,
    required this.canvas,
    required this.size,
    required this.irCalculatorResult,
    required this.visibleArea,
    this.pathApproximation,
  });

  static void addLine(Vector2 a, Path path) => path.lineTo(a.x, -a.y);

  void drawCircle(Vector2 a, Paint paint, {double radius = irReadingsRadius}) {
    final o = Offset(a.x, -a.y);
    canvas.drawCircle(o, radius, paint);
  }

  @override
  void paint() {
    final leftPath = Path();
    final rightPath = Path();

    (Vector2, Vector2) first = irCalculatorResult.wheelPositions.first;

    leftPath.moveTo(first.$1.x, -first.$1.y);
    rightPath.moveTo(first.$2.x, -first.$2.y);

    for (int i = 0; i < irCalculatorResult.length; ++i) {
      final irPositions = irCalculatorResult.irData[i];

      if (settings.showTracks) {
        final wheelPositions = irCalculatorResult.wheelPositions[i];
        addLine(wheelPositions.$1, leftPath);
        addLine(wheelPositions.$2, rightPath);
      }

      final mp = irPositions.$2.position;
      if (visionCenter.distanceToSquared(mp) > a) continue; // rough pre filter

      for (final ir in [irPositions.$1, irPositions.$2, irPositions.$3]) {
        if (ir.value < settings.irReadingsThreshold && expandedArea.intersectsWithVector2(ir.position)) {
          paintCache.color = irToColor(ir.value);
          drawCircle(ir.position, paintCache);
        }
      }
    }

    if (settings.showTracks) {
      canvas.drawPath(rightPath, rightTrackPaint);
      canvas.drawPath(leftPath, leftTrackPaint);
    }

    if (settings.showCalculatedPath) paintReducedLineEstimate();
  }

  Color irToColor(final int rawIr) {
    int gray = rawIr ~/ 4;

    if (gray > 255) {
      gray = 255;
    }

    return Color.fromARGB(255, gray, gray, gray);
  }

  void paintReducedLineEstimate() {
    if (pathApproximation == null) return;

    final path = Path();

    for (final point in pathApproximation!) {
      if (expandedArea.intersectsWithVector2(point)) {
        drawCircle(point, Paint()..color = Colors.white);
      }
      addLine(point, path);
    }

    canvas.drawPath(
      path,
      Paint()
        ..strokeWidth = irReadingsRadius
        ..color = Colors.blue
        ..style = PaintingStyle.stroke,
    );
  }
}
