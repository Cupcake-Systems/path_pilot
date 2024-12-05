import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:path_pilot/editor/painters/simulation_painter.dart';

import '../../robi_api/ir_read_api.dart';
import '../../robi_api/robi_utils.dart';
import 'ir_read_painter.dart';
import 'line_painter.dart';
import 'line_painter_settings/line_painter_visibility_settings.dart';

const double bottomPadding = 10;
const double topPadding = 10;
const double leftPadding = 18;
const double rightPadding = 18;

class ForegroundPainter extends CustomPainter {
  final double scale;
  final bool showDeveloperInfo;
  final LinePainterVisibilitySettings visibilitySettings;
  final SimulationResult? simulationResult;
  final (IrCalculatorResult, IrReadPainterSettings)? irCalculatorResultAndSettings;
  final Measurement? currentMeasurement;
  final RobiState? robiState;
  final RobiStateType robiStateType;

  // Developer info
  static int _drawCallsCount = 0;
  static final _drawTimeSw = Stopwatch();
  static final _last100FramesTimer = Stopwatch();
  static Duration _last100FramesTime = Duration.zero;

  const ForegroundPainter({
    required this.scale,
    required this.showDeveloperInfo,
    required this.visibilitySettings,
    required this.simulationResult,
    required this.irCalculatorResultAndSettings,
    required this.currentMeasurement,
    required this.robiState,
    required this.robiStateType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showDeveloperInfo) {
      _devPaint(canvas, size);
    } else {
      _paint(canvas, size);
    }
  }

  void _paint(Canvas canvas, Size size) {
    if (visibilitySettings.showRobiStateInfo) paintRobiState(canvas, size);
    if (visibilitySettings.showIrMeasurementInfo) paintIrMeasurement(canvas, size);
    if (visibilitySettings.showLengthScale) paintScale(canvas, size);

    if (visibilitySettings.showVelocityScale) {
      if (simulationResult != null && visibilitySettings.showSimulation && simulationResult!.instructionResults.isNotEmpty) {
        paintVelocityScale(canvas, size, simulationResult!.maxTargetedVelocity);
      } else if (irCalculatorResultAndSettings != null && visibilitySettings.showIrTrackPath && irCalculatorResultAndSettings!.$1.length > 0) {
        paintVelocityScale(canvas, size, irCalculatorResultAndSettings!.$1.maxVelocity);
      }
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

  void paintScale(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..strokeWidth = 1
      ..color = white;

    canvas.drawLine(Offset(leftPadding + 1, size.height - bottomPadding), Offset(leftPadding + 99, size.height - bottomPadding), paint);
    canvas.drawLine(Offset(leftPadding, size.height - bottomPadding - 5), Offset(leftPadding, size.height - bottomPadding + 5), paint);
    canvas.drawLine(Offset(leftPadding + 100, size.height - bottomPadding - 5), Offset(leftPadding + 100, size.height - bottomPadding + 5), paint);

    paintText("${(100.0 / scale * 100).toStringAsFixed(2)}cm", Offset(leftPadding + 50, size.height - bottomPadding - 22), canvas, size, textAlign: TextAlign.center);
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
    final last100FpsText = _last100FramesTime.inMilliseconds == 0 ? "" : " (${(100 / (_last100FramesTime.inMilliseconds / 1000)).round()} FPS)";

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
    if (robiState == null) return;

    final rs = robiState!.asInnerOuter();
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
    paintText("0", lineStart.translate(0, -22), canvas, size, textAlign: TextAlign.center);
    paintText("${(maxTargetedVelocity * 100).round()}cm/s", lineEnd.translate(1, -22), canvas, size, textAlign: TextAlign.right);
  }

  @override
  bool shouldRepaint(covariant ForegroundPainter oldDelegate) => true;
}
