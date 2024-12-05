import 'package:flutter/material.dart';
import 'package:path_pilot/editor/painters/ir_read_painter.dart';
import 'package:path_pilot/editor/painters/obstacles_painter.dart';
import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:path_pilot/editor/painters/simulation_painter.dart';
import 'package:path_pilot/robi_api/ir_read_api.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart' show Aabb2, Vector2;

import '../obstacles/obstacle.dart';
import 'abstract_painter.dart';
import 'line_painter_settings/line_painter_visibility_settings.dart';

const Color white = Color(0xFFFFFFFF);

class LinePainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final RobiConfig robiConfig;
  final SimulationResult? simulationResult;
  final InstructionResult? highlightedInstruction;
  final (IrCalculatorResult, IrReadPainterSettings)? irCalculatorResultAndSettings;
  final List<Vector2>? irPathApproximation;
  final RobiState? robiState;
  final List<Obstacle>? obstacles;
  final LinePainterVisibilitySettings visibilitySettings;

  const LinePainter({
    super.repaint,
    required this.scale,
    required this.robiConfig,
    required this.simulationResult,
    required this.highlightedInstruction,
    required this.irCalculatorResultAndSettings,
    required this.irPathApproximation,
    required this.offset,
    required this.robiState,
    required this.obstacles,
    required this.visibilitySettings,
  });

  void paintGrid(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 1
      ..color = white.withAlpha(100);

    final int xLineCount = size.width ~/ scale + 1;
    final int yLineCount = size.height ~/ scale + 1;

    for (double xo = size.width / 2 + offset.dx % scale - scale * xLineCount; xo < xLineCount * scale; xo += scale) {
      canvas.drawLine(Offset(xo, 0), Offset(xo, size.height), paint);
    }

    for (double yo = size.height / 2 + offset.dy % scale - scale * yLineCount; yo < yLineCount * scale; yo += scale) {
      canvas.drawLine(Offset(0, yo), Offset(size.width, yo), paint);
    }

    paint.color = white.withAlpha(50);

    for (double xo = size.width / 2 + offset.dx % scale - scale * xLineCount + 0.5 * scale; xo < xLineCount * scale; xo += scale) {
      canvas.drawLine(Offset(xo, 0), Offset(xo, size.height), paint);
    }

    for (double yo = size.height / 2 + offset.dy % scale - scale * yLineCount + 0.5 * scale; yo < yLineCount * scale; yo += scale) {
      canvas.drawLine(Offset(0, yo), Offset(size.width, yo), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {

    canvas.clipRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      doAntiAlias: false,
    );

    if (visibilitySettings.showGrid) paintGrid(canvas, size);

    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
    canvas.scale(scale);
    canvas.save();

    final visibleArea = Aabb2.minMax(
      Vector2(-offset.dx - center.dx, offset.dy - center.dy) / scale,
      Vector2(-offset.dx + center.dx, offset.dy + center.dy) / scale,
    );

    final painters = <MyPainter>[
      if (obstacles != null && visibilitySettings.showObstacles)
        ObstaclesPainter(
          canvas: canvas,
          obstacles: obstacles!,
          visibleArea: visibleArea,
        ),
      if (simulationResult != null && visibilitySettings.showSimulation)
        SimulationPainter(
          simulationResult: simulationResult!,
          canvas: canvas,
          visibleArea: visibleArea,
          highlightedInstruction: highlightedInstruction,
        ),
      if (irCalculatorResultAndSettings != null)
        IrReadPainter(
          visibleArea: visibleArea,
          robiConfig: robiConfig,
          settings: irCalculatorResultAndSettings!.$2,
          canvas: canvas,
          size: size,
          irCalculatorResult: irCalculatorResultAndSettings!.$1,
          pathApproximation: irPathApproximation,
          showIrTrackPath: visibilitySettings.showIrTrackPath,
          showCalculatedPath: visibilitySettings.showIrPathApproximation,
          showIrReadings: visibilitySettings.showIrRead,
        ),
      if (robiState != null && visibilitySettings.showRobi)
        RobiPainter(
          robiState: robiState!,
          canvas: canvas,
        ),
    ];

    canvas.restore();

    for (final painter in painters) {
      canvas.save();
      painter.paint();
      canvas.restore();
    }
  }
}
