import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/editor/painters/ir_read_painter.dart';
import 'package:path_pilot/editor/painters/obstacles_painter.dart';
import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:path_pilot/editor/painters/simulation_painter.dart';
import 'package:path_pilot/robi_api/ir_read_api.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart' show Aabb2, Vector2;

import '../obstacles/obstacle.dart';
import 'abstract_painter.dart';

const Color white = Color(0xFFFFFFFF);
const double bottomPadding = 100;
const double topPadding = 10;
const double leftPadding = 18;
const double rightPadding = 18;

class LinePainter extends CustomPainter {
  final double scale;
  final Offset offset;
  final RobiConfig robiConfig;
  final SimulationResult? simulationResult;
  final IrReadPainterSettings? irReadPainterSettings;
  final InstructionResult? highlightedInstruction;
  final IrCalculatorResult? irCalculatorResult;
  final List<Vector2>? irPathApproximation;
  final Measurement? currentMeasurement;
  final RobiState robiState;
  final RobiStateType robiStateType;
  final List<Obstacle>? obstacles;

  // Developer info
  static int _drawCallsCount = 0;
  static final _drawTimeSw = Stopwatch();
  static final _last100FramesTimer = Stopwatch();
  static Duration _last100FramesTime = Duration.zero;

  const LinePainter({
    super.repaint,
    required this.scale,
    required this.robiConfig,
    required this.irReadPainterSettings,
    required this.simulationResult,
    required this.highlightedInstruction,
    required this.irCalculatorResult,
    required this.irPathApproximation,
    required this.offset,
    required this.robiState,
    required this.robiStateType,
    required this.obstacles,
    required this.currentMeasurement,
  });

  static void paintText(String text, Offset offset, Canvas canvas, Size size, {TextStyle? textStyle, TextAlign textAlign = TextAlign.start}) {
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr, textAlign: textAlign);
    textPainter.layout(minWidth: 0, maxWidth: size.width);

    switch (textAlign) {
      case TextAlign.center:
        textPainter.paint(canvas, offset.translate(-textPainter.width / 2, 0));
        break;
      case TextAlign.right:
      case TextAlign.end:
        textPainter.paint(canvas, offset.translate(-textPainter.width, 0));
        break;
      default:
        textPainter.paint(canvas, offset);
        break;
    }
  }

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

  void paintScale(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 1
      ..color = white;

    canvas.drawLine(Offset(leftPadding + 1, size.height - bottomPadding), Offset(leftPadding + 99, size.height - bottomPadding), paint);
    canvas.drawLine(Offset(leftPadding, size.height - bottomPadding - 5), Offset(leftPadding, size.height - bottomPadding + 5), paint);
    canvas.drawLine(Offset(leftPadding + 100, size.height - bottomPadding - 5), Offset(leftPadding + 100, size.height - bottomPadding + 5), paint);

    LinePainter.paintText("${(100.0 / scale * 100).toStringAsFixed(2)}cm", Offset(leftPadding + 50, size.height - bottomPadding - 22), canvas, size, textAlign: TextAlign.center);
  }

  void paintIrMeasurement(Canvas canvas, Size size) {
    if (currentMeasurement == null) return;

    final measurement = currentMeasurement!;

    final leftDir = measurement.leftFwd ? "F" : "B";
    final rightDir = measurement.rightFwd ? "F" : "B";

    String noString = "";

    if (measurement.readingIndex != null) {
      noString = "Reading No.: ${measurement.readingIndex! + 1}\n";
    }

    String text = """${noString}IR: (${measurement.leftIr}, ${measurement.middleIr}, ${measurement.rightIr})
Freq.: (${measurement.motorLeftFreq}, ${measurement.motorRightFreq})Hz
Dir.: $leftDir, $rightDir""";
    paintText(
      text,
      Offset(size.width - rightPadding, topPadding),
      canvas,
      size,
      textStyle: const TextStyle(
        fontFamily: "RobotoMono",
        fontSize: 12,
      ),
      textAlign: TextAlign.right,
    );
  }

  void paintDeveloperInfo(Canvas canvas, Size size) {

    final last100FpsText = _last100FramesTime.inMilliseconds == 0? "" : " (${(100 / (_last100FramesTime.inMilliseconds / 1000)).round()} FPS)";

    final String text = """
Developer Info
Draw Calls: $_drawCallsCount
Last Draw Time: ${_drawTimeSw.elapsedMilliseconds}ms
Last 100 Frames Time: ${_last100FramesTime.inMilliseconds}ms$last100FpsText
""";

    paintText(
      text,
      const Offset(leftPadding, 90),
      canvas,
      size,
      textStyle: const TextStyle(
        fontFamily: "RobotoMono",
        fontSize: 12,
      ),
    );
  }

  void paintRobiState(Canvas canvas, Size size) {
    final rs = robiState.asInnerOuter();
    final String xPosText = (rs.position.x * 100).toStringAsFixed(0);
    final String innerVelText = (rs.innerVelocity * 100).toStringAsFixed(0);
    final String innerAccelText = (rs.innerAcceleration * 100).toStringAsFixed(0);
    final String posSpace = " " * (8 - xPosText.length);
    final String velSpace = " " * (6 - innerVelText.length);
    final String accelSpace = " " * (5 - innerAccelText.length);

    String robiStateText = """
Rot.: ${rs.rotation.toStringAsFixed(2)}°
Pos.: X ${xPosText}cm${posSpace}Y ${(rs.position.y * 100).toInt()}cm
Vel.: I ${innerVelText}cm/s${velSpace}O ${(rs.outerVelocity * 100).toInt()}cm/s
Acc.: I ${innerAccelText}cm/s²${accelSpace}O ${(rs.outerAcceleration * 100).toInt()}cm/s²""";

    if (robiStateType == RobiStateType.leftRight) {
      robiStateText = robiStateText.replaceAll("I ", "L ").replaceAll("O ", "R ");
    }

    paintText(
      robiStateText,
      const Offset(leftPadding, topPadding),
      canvas,
      size,
      textStyle: const TextStyle(fontFamily: "RobotoMono", fontSize: 12),
    );
  }

  void paintVelocityScale(Canvas canvas, Size size, double maxTargetedVelocity) {
    if (maxTargetedVelocity <= 0) return;

    List<Color> colors = [velToColor(0, maxTargetedVelocity), velToColor(maxTargetedVelocity, maxTargetedVelocity)];

    final lineStart = Offset(size.width - rightPadding - 100, size.height - bottomPadding);
    final lineEnd = Offset(size.width - rightPadding, size.height - bottomPadding);

    final accelerationPaint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        radius: 0.5 / sqrt2,
      ).createShader(Rect.fromCircle(center: lineStart, radius: lineEnd.dx - lineStart.dx))
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
    LinePainter.paintText("0", lineStart.translate(0, -22), canvas, size, textAlign: TextAlign.center);
    LinePainter.paintText("${(maxTargetedVelocity * 100).round()}cm/s", lineEnd.translate(1, -22), canvas, size, textAlign: TextAlign.right);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    if (SettingsStorage.developerMode) {
      _devPaint(canvas, size);
    } else {
      _paint(canvas, size);
    }
  }

  void _devPaint(Canvas canvas, Size size) {
    if (_drawCallsCount % 100 == 0) {
      _last100FramesTimer.stop();
      _last100FramesTime = _last100FramesTimer.elapsed;
      _last100FramesTimer.reset();
      _last100FramesTimer.start();
    }

    _drawCallsCount++;
    _drawTimeSw.start();

    _paint(canvas, size);

    _drawTimeSw.stop();

    paintDeveloperInfo(canvas, size);

    _drawTimeSw.reset();
  }

  void _paint(Canvas canvas, Size size) {
    canvas.save();

    canvas.clipRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      doAntiAlias: false,
    );
    paintGrid(canvas, size);

    final Offset center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
    canvas.scale(scale);
    canvas.save();

    final Aabb2 visibleArea = Aabb2.minMax(
      Vector2(-offset.dx - center.dx, offset.dy - center.dy) / scale,
      Vector2(-offset.dx + center.dx, offset.dy + center.dy) / scale,
    );

    if (irCalculatorResult != null) assert(irReadPainterSettings != null);
    final List<MyPainter> painters = [
      if (obstacles != null)
        ObstaclesPainter(
          canvas: canvas,
          obstacles: obstacles!,
          visibleArea: visibleArea,
        ),
      if (simulationResult != null)
        SimulationPainter(
          simulationResult: simulationResult!,
          canvas: canvas,
          visibleArea: visibleArea,
          highlightedInstruction: highlightedInstruction,
        ),
      if (irCalculatorResult != null)
        IrReadPainter(
          visibleArea: visibleArea,
          robiConfig: robiConfig,
          settings: irReadPainterSettings!,
          canvas: canvas,
          size: size,
          irCalculatorResult: irCalculatorResult!,
          pathApproximation: irPathApproximation,
        ),
      RobiPainter(
        robiState: robiState,
        canvas: canvas,
      ),
    ];

    canvas.restore();

    for (final painter in painters) {
      canvas.save();
      painter.paint();
      canvas.restore();
    }

    canvas.restore();

    paintRobiState(canvas, size);
    paintIrMeasurement(canvas, size);
    paintScale(canvas, size);

    if (simulationResult != null) {
      paintVelocityScale(canvas, size, simulationResult!.maxTargetedVelocity);
    } else if (irCalculatorResult != null) {
      paintVelocityScale(canvas, size, irCalculatorResult!.maxVelocity);
    }
  }
}
