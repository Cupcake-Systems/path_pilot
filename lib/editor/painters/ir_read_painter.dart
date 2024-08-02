import 'dart:math';

import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/abstract_painter.dart';

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
  final IrReadResult irReadResult;
  final IrReadPainterSettings settings;
  final Canvas canvas;
  final Size size;

  late final mc = sqrt(
      pow(robiConfig.distanceWheelIr, 2) + pow(robiConfig.trackWidth / 2, 2));
  late final rc = sqrt(pow(robiConfig.distanceWheelIr, 2) +
      pow(robiConfig.trackWidth / 2 - 0.01, 2));
  late final lc = sqrt(pow(robiConfig.distanceWheelIr, 2) +
      pow(robiConfig.trackWidth / 2 + 0.01, 2));
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
    required this.irReadResult,
    required this.settings,
    required this.canvas,
    required this.size,
  });

  @override
  void paint() {
    Path leftPath = Path();
    Path rightPath = Path();

    void addLine(Offset a, Path path) {
      path.lineTo(a.dx * scale + middle.dx, a.dy * scale + middle.dy);
    }

    Offset lastRightOffset = Offset(0, robiConfig.trackWidth / 2);
    Offset lastLeftOffset = Offset(0, -robiConfig.trackWidth / 2);

    double rotationRad = 0;

    leftPath.moveTo(lastLeftOffset.dx * scale + middle.dx,
        lastLeftOffset.dy * scale + middle.dy);
    rightPath.moveTo(lastRightOffset.dx * scale + middle.dx,
        lastRightOffset.dy * scale + middle.dy);
    List<List<(int value, Offset offset)>> data = [];

    for (final measurement in irReadResult.measurements) {
      double leftVel =
          freqToVel(measurement.motorLeftFreq, robiConfig.wheelRadius);
      if (!measurement.leftFwd) leftVel *= -1;
      double rightVel =
          freqToVel(measurement.motorRightFreq, robiConfig.wheelRadius);
      if (!measurement.rightFwd) rightVel *= -1;

      final angularVelocityRad = (rightVel - leftVel) / robiConfig.trackWidth;
      rotationRad += angularVelocityRad * irReadResult.resolution;

      final rightDistance = rightVel * irReadResult.resolution;
      final leftDistance = leftVel * irReadResult.resolution;

      final newRightOffset = lastRightOffset.translate(
          cos(rotationRad) * rightDistance, -sin(rotationRad) * rightDistance);
      final newLeftOffset = lastLeftOffset.translate(
          cos(rotationRad) * leftDistance, -sin(rotationRad) * leftDistance);

      if (settings.showTracks) {
        addLine(newRightOffset, rightPath);
        addLine(newLeftOffset, leftPath);
      }

      // IR Stuff

      double mAlpha = rotationRad +
          pi / 2 -
          atan(robiConfig.distanceWheelIr / (robiConfig.trackWidth / 2));
      double rAlpha = rotationRad +
          pi / 2 -
          atan(robiConfig.distanceWheelIr / (robiConfig.trackWidth / 2 - 0.01));
      double lAlpha = rotationRad +
          pi / 2 -
          atan(robiConfig.distanceWheelIr / (robiConfig.trackWidth / 2 + 0.01));

      Offset mIrPosition =
          newRightOffset.translate(cos(mAlpha) * mc, -sin(mAlpha) * mc);
      Offset rIrPosition =
          newRightOffset.translate(cos(rAlpha) * rc, -sin(rAlpha) * rc);
      Offset lIrPosition =
          newRightOffset.translate(cos(lAlpha) * lc, -sin(lAlpha) * lc);

      data.add([
        (measurement.leftIr, lIrPosition * scale + middle),
        (measurement.middleIr, mIrPosition * scale + middle),
        (measurement.rightIr, rIrPosition * scale + middle)
      ]);

      if (measurement.rightIr < settings.irReadingsThreshold) {
        canvas.drawCircle(rIrPosition * scale + middle, 0.005 * scale,
            irToPaint(measurement.rightIr));
      }
      if (measurement.leftIr < settings.irReadingsThreshold) {
        canvas.drawCircle(lIrPosition * scale + middle, 0.005 * scale,
            irToPaint(measurement.leftIr));
      }
      if (measurement.middleIr < settings.irReadingsThreshold) {
        canvas.drawCircle(mIrPosition * scale + middle, 0.005 * scale,
            irToPaint(measurement.middleIr));
      }

      lastRightOffset = newRightOffset;
      lastLeftOffset = newLeftOffset;
    }

    if (settings.showTracks) {
      canvas.drawPath(rightPath, rightTrackPaint);
      canvas.drawPath(leftPath, leftTrackPaint);
    }

    if (settings.showCalculatedPath) paintLineEstimate(data);
  }

  Paint irToPaint(int rawIr) {
    int gray = rawIr ~/ 4;

    if (gray > 255) {
      gray = 255;
    }

    return Paint()..color = Color.fromARGB(255, gray, gray, gray);
  }

  void paintLineEstimate(List<List<(int value, Offset offset)>> data) {
    List<Offset> selectedPoints = filterPoints(data);
    paintSmoothLineEstimate(selectedPoints);
  }

  static List<Offset> filterPoints(
      List<List<(int value, Offset offset)>> measurements) {
    List<Offset> selectedPoints = [];
    for (int i = 1; i < measurements.length - 1; i++) {
      if (measurements[i][1].$1 > 100) {
        continue;
      }
      selectedPoints.add(measurements[i][1].$2);
    }
    return selectedPoints;
  }

  void paintSmoothLineEstimate(List<Offset> selectedPoints) {
    final path = Path();
    path.moveTo(middle.dx, middle.dy);

    final catmullRomSpline = CatmullRomSpline(selectedPoints);

    final smoothPoints = <Offset>[];
    const resolution = 100; // Increase for higher smoothness
    for (double t = 0; t <= 1; t += 1 / resolution) {
      final o = catmullRomSpline.transform(t);
      smoothPoints.add(o);
    }

    for (var point in smoothPoints) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(
        path,
        Paint()
          ..strokeWidth = 0.005 * scale
          ..color = Colors.blue
          ..style = PaintingStyle.stroke);
  }
}
