import 'dart:io';
import 'dart:math';

import 'package:robi_line_drawer/editor/ir_line_approximation/ramers_douglas.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart';

class Measurement {
  final int motorLeftFreq, motorRightFreq, leftIr, middleIr, rightIr;
  final bool leftFwd, rightFwd;

  const Measurement({
    required this.motorLeftFreq,
    required this.motorRightFreq,
    required this.leftIr,
    required this.middleIr,
    required this.rightIr,
    required this.leftFwd,
    required this.rightFwd,
  });

  factory Measurement.fromLine(String line) {
    line = line.trim();
    final s = line.split(" : ");
    final motorSplit = s[0].split(" ");
    final fwdSplit = s[1].split(" ");
    final irSplit = s[2].split(", ");
    return Measurement(
      motorLeftFreq: int.parse(motorSplit[0]),
      motorRightFreq: int.parse(motorSplit[1]),
      leftIr: int.parse(irSplit[0]),
      middleIr: int.parse(irSplit[1]),
      rightIr: int.parse(irSplit[2]),
      leftFwd: bool.parse(fwdSplit[0], caseSensitive: false),
      rightFwd: bool.parse(fwdSplit[1], caseSensitive: false),
    );
  }
}

class IrReadResult {
  final double resolution;
  final List<Measurement> measurements;

  const IrReadResult({required this.resolution, required this.measurements});

  factory IrReadResult.fromData(String data) {
    final lines = data.trim().split("\n");
    return IrReadResult(
      resolution: double.parse(lines[0].trim()),
      measurements:
          lines.sublist(1).map((e) => Measurement.fromLine(e)).toList(),
    );
  }

  factory IrReadResult.fromFile(File file) =>
      IrReadResult.fromData(file.readAsStringSync());
}

class IrReading {
  final int value;
  final Vector2 position;

  const IrReading(this.value, this.position);
}

class IrCalculatorResult {
  final List<(IrReading left, IrReading middle, IrReading right)> irData;
  final List<(Vector2 left, Vector2 right)> wheelPositions;

  const IrCalculatorResult({
    required this.irData,
    required this.wheelPositions,
  });
}

class IrCalculator {
  final IrReadResult irReadResult;

  IrCalculator({required this.irReadResult});

  IrCalculatorResult calculate(RobiConfig robiConfig) {
    final mc = sqrt(
        pow(robiConfig.distanceWheelIr, 2) + pow(robiConfig.trackWidth / 2, 2));
    final rc = sqrt(pow(robiConfig.distanceWheelIr, 2) +
        pow(robiConfig.trackWidth / 2 - 0.01, 2));
    final lc = sqrt(pow(robiConfig.distanceWheelIr, 2) +
        pow(robiConfig.trackWidth / 2 + 0.01, 2));

    Vector2 lastRightOffset = Vector2(0, -robiConfig.trackWidth / 2);
    Vector2 lastLeftOffset = Vector2(0, robiConfig.trackWidth / 2);

    double rotationRad = 0;
    List<(IrReading, IrReading, IrReading)> irData = [];
    List<(Vector2, Vector2)> wheelPositions = [];

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

      final newRightOffset = lastRightOffset +
          Vector2(cos(rotationRad) * rightDistance,
              sin(rotationRad) * rightDistance);
      final newLeftOffset = lastLeftOffset +
          Vector2(
              cos(rotationRad) * leftDistance, sin(rotationRad) * leftDistance);

      wheelPositions.add((newLeftOffset, newRightOffset));

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

      Vector2 mIrPosition =
          newRightOffset + Vector2(cos(mAlpha) * mc, sin(mAlpha) * mc);
      Vector2 rIrPosition =
          newRightOffset + Vector2(cos(rAlpha) * rc, sin(rAlpha) * rc);
      Vector2 lIrPosition =
          newRightOffset + Vector2(cos(lAlpha) * lc, sin(lAlpha) * lc);

      irData.add((
        IrReading(measurement.leftIr, lIrPosition),
        IrReading(measurement.middleIr, mIrPosition),
        IrReading(measurement.rightIr, rIrPosition)
      ));

      lastRightOffset = newRightOffset;
      lastLeftOffset = newLeftOffset;
    }

    return IrCalculatorResult(irData: irData, wheelPositions: wheelPositions);
  }

  List<Vector2> pathApproximation(IrCalculatorResult irCalculatorResult,
      int minBlackLevel, double tolerance) {
    List<Vector2> blackPoints = [Vector2(0, 0)];

    for (final measurement in irCalculatorResult.irData) {
      if (measurement.$2.value < minBlackLevel) {
        blackPoints.add(measurement.$2.position);
      }
    }

    List<Vector2> simplifiedPoints =
        pointsToVector2(RamerDouglasPeucker.ramerDouglasPeucker(
      vectorsToPoints(blackPoints),
      pow(2, tolerance / 100) - 1,
    ));

    return simplifiedPoints;
  }
}
