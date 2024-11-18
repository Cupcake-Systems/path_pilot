import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_pilot/editor/painters/abstract_painter.dart';
import 'package:path_pilot/editor/painters/simulation_painter.dart';
import 'package:path_pilot/helper/geometry.dart';
import 'package:vector_math/vector_math.dart' show Aabb2, Vector2;

import '../../robi_api/ir_read_api.dart';
import '../../robi_api/robi_utils.dart';
import 'line_painter.dart';

class IrReadPainterSettings {
  final bool showCalculatedPath, showVelocityPath;
  final int irReadingsThreshold, irInclusionThreshold;
  final double ramerDouglasPeuckerTolerance;

  const IrReadPainterSettings({
    required this.irReadingsThreshold,
    required this.showCalculatedPath,
    required this.ramerDouglasPeuckerTolerance,
    required this.irInclusionThreshold,
    required this.showVelocityPath,
  });

  IrReadPainterSettings copyWith({
    int? irReadingsThreshold,
    bool? showCalculatedPath,
    bool? showTracks,
    double? ramerDouglasPeuckerTolerance,
    int? irInclusionThreshold,
    bool? showVelocityPath,
  }) {
    return IrReadPainterSettings(
      irReadingsThreshold: irReadingsThreshold ?? this.irReadingsThreshold,
      showCalculatedPath: showCalculatedPath ?? this.showCalculatedPath,
      ramerDouglasPeuckerTolerance: ramerDouglasPeuckerTolerance ?? this.ramerDouglasPeuckerTolerance,
      irInclusionThreshold: irInclusionThreshold ?? this.irInclusionThreshold,
      showVelocityPath: showVelocityPath ?? this.showVelocityPath,
    );
  }
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
  late final Aabb2 expandedAreaForIrReadings = Aabb2.minMax(
    visibleArea.min - Vector2.all(irReadingsRadius),
    visibleArea.max + Vector2.all(irReadingsRadius),
  );
  late final Aabb2 expandedAreaForVelocityLines = Aabb2.minMax(
    visibleArea.min - Vector2.all(robiConfig.wheelWidth),
    visibleArea.max + Vector2.all(robiConfig.wheelWidth),
  );
  late final Vector2 visionCenter = visibleArea.center;
  late final double centerMaxDistance = visionCenter.distanceTo(expandedAreaForIrReadings.max);
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
    paintCache.strokeWidth = robiConfig.wheelWidth;

    for (int i = 0; i < irCalculatorResult.length; ++i) {
      final irPositions = irCalculatorResult.irData[i];
      final robiState = irCalculatorResult.robiStates[i];

      if (settings.showVelocityPath && i < irCalculatorResult.length - 1) {
        final leftVel = robiState.leftVelocity;
        final rightVel = robiState.rightVelocity;

        final lwVec = irCalculatorResult.wheelPositions[i].$1;
        final rwVec = irCalculatorResult.wheelPositions[i].$2;

        final nextLwVec = irCalculatorResult.wheelPositions[i + 1].$1;
        final nextRwVec = irCalculatorResult.wheelPositions[i + 1].$2;

        if (isLineVisibleFast(expandedAreaForVelocityLines, lwVec, nextLwVec)) {
          paintCache.color = velToColor(leftVel, irCalculatorResult.maxVelocity);
          canvas.drawLine(vecToOffset(lwVec), vecToOffset(nextLwVec), paintCache);
        }

        if (isLineVisibleFast(expandedAreaForVelocityLines, rwVec, nextRwVec)) {
          paintCache.color = velToColor(rightVel, irCalculatorResult.maxVelocity);
          canvas.drawLine(vecToOffset(rwVec), vecToOffset(nextRwVec), paintCache);
        }
      }

      final mp = irPositions.$2.position;
      if (visionCenter.distanceToSquared(mp) > a) continue; // rough pre filter

      for (final ir in [irPositions.$1, irPositions.$2, irPositions.$3]) {
        if (ir.value < settings.irReadingsThreshold && expandedAreaForIrReadings.intersectsWithVector2(ir.position)) {
          paintCache.color = irToColor(ir.value);
          drawCircle(ir.position, paintCache);
        }
      }
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
      if (expandedAreaForIrReadings.intersectsWithVector2(point)) {
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
