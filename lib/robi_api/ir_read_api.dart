import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:robi_line_drawer/editor/ir_line_approximation/ramers_douglas.dart';
import 'package:robi_line_drawer/editor/painters/robi_painter.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:robi_line_drawer/robi_api/simulator.dart';
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

  Measurement.zero()
      : this(
          motorLeftFreq: 0,
          motorRightFreq: 0,
          leftIr: 0,
          middleIr: 0,
          rightIr: 0,
          leftFwd: true,
          rightFwd: true,
        );

  /// Measurement binary structure documentation:
  /// https://github.com/Finnomator/robi_line_drawer/wiki/IR-Read-Result-Binary-File-Definition#64-bit-measurement-format
  factory Measurement.fromLine(ByteData line) {
    final readAndFwdByte = line.getUint32(4);
    return Measurement(
      motorLeftFreq: line.getUint16(0),
      motorRightFreq: line.getUint16(2),
      leftIr: (readAndFwdByte >> 20) & 0x3FF,
      middleIr: (readAndFwdByte >> 10) & 0x3FF,
      rightIr: readAndFwdByte & 0x3FF,
      leftFwd: (readAndFwdByte & (1 << 31)) != 0,
      rightFwd: (readAndFwdByte & (1 << 30)) != 0,
    );
  }
}

class IrReadResult {
  final double resolution;
  final List<Measurement> measurements;
  late final double totalTime = resolution * measurements.length;

  IrReadResult({required this.resolution, required this.measurements});

  /// Binary file structure documentation:
  /// https://github.com/Finnomator/robi_line_drawer/wiki/IR-Read-Result-Binary-File-Definition
  factory IrReadResult.fromData(ByteBuffer data) {
    final dataLineCount = data.asByteData(2).lengthInBytes ~/ 8;

    return IrReadResult(
      resolution: data.asByteData(0, 2).getUint16(0) / 1000,
      measurements: [for (int i = 0; i < dataLineCount; ++i) Measurement.fromLine(data.asByteData(2 + i * 8, 8))],
    );
  }

  factory IrReadResult.fromFile(File file) => IrReadResult.fromData(file.readAsBytesSync().buffer);
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

  const IrCalculator({required this.irReadResult});

  RobiState getRobiStateAtMeasurement(final Measurement measurement, final RobiConfig robiConfig) {
    Vector2 lastRightOffset = Vector2(0, -robiConfig.trackWidth / 2);
    Vector2 lastLeftOffset = Vector2(0, robiConfig.trackWidth / 2);

    double lastLeftVel = freqToVel(irReadResult.measurements[0].motorLeftFreq, robiConfig.wheelRadius);
    double lastRightVel = freqToVel(irReadResult.measurements[0].motorRightFreq, robiConfig.wheelRadius);

    double rotationRad = 0;

    for (final m in irReadResult.measurements) {
      double leftVel = freqToVel(m.motorLeftFreq, robiConfig.wheelRadius);
      if (!m.leftFwd) leftVel *= -1;
      double rightVel = freqToVel(m.motorRightFreq, robiConfig.wheelRadius);
      if (!m.rightFwd) rightVel *= -1;

      final leftAccel = (leftVel - lastLeftVel) / irReadResult.resolution;
      final rightAccel = (rightVel - lastRightVel) / irReadResult.resolution;

      final angularVelocityRad = (rightVel - leftVel) / robiConfig.trackWidth;
      rotationRad += angularVelocityRad * irReadResult.resolution;

      final rightDistance = rightVel * irReadResult.resolution;
      final leftDistance = leftVel * irReadResult.resolution;

      final newRightOffset = lastRightOffset + polarToCartesianRad(rotationRad, rightDistance);
      final newLeftOffset = lastLeftOffset + polarToCartesianRad(rotationRad, leftDistance);

      if (m == measurement) {
        return RobiState(
          position: (lastLeftOffset + lastRightOffset) / 2,
          rotation: rotationRad * radians2Degrees,
          innerVelocity: leftVel,
          outerVelocity: rightVel,
          innerAcceleration: leftAccel,
          outerAcceleration: rightAccel,
        );
      }

      lastRightOffset = newRightOffset;
      lastLeftOffset = newLeftOffset;
      lastLeftVel = leftVel;
      lastRightVel = rightVel;
    }

    throw UnsupportedError("Measurement not found");
  }

  IrCalculatorResult calculate(RobiConfig robiConfig) {
    final mc = sqrt(pow(robiConfig.distanceWheelIr, 2) + pow(robiConfig.trackWidth / 2, 2));
    final rc = sqrt(pow(robiConfig.distanceWheelIr, 2) + pow(robiConfig.trackWidth / 2 - robiConfig.irDistance, 2));
    final lc = sqrt(pow(robiConfig.distanceWheelIr, 2) + pow(robiConfig.trackWidth / 2 + robiConfig.irDistance, 2));

    Vector2 lastRightOffset = Vector2(0, -robiConfig.trackWidth / 2);
    Vector2 lastLeftOffset = Vector2(0, robiConfig.trackWidth / 2);

    double rotationRad = 0;
    List<(IrReading, IrReading, IrReading)> irData = [];
    List<(Vector2, Vector2)> wheelPositions = [];

    for (final measurement in irReadResult.measurements) {
      double leftVel = freqToVel(measurement.motorLeftFreq, robiConfig.wheelRadius);
      if (!measurement.leftFwd) leftVel *= -1;
      double rightVel = freqToVel(measurement.motorRightFreq, robiConfig.wheelRadius);
      if (!measurement.rightFwd) rightVel *= -1;

      final angularVelocityRad = (rightVel - leftVel) / robiConfig.trackWidth;
      rotationRad += angularVelocityRad * irReadResult.resolution;

      final rightDistance = rightVel * irReadResult.resolution;
      final leftDistance = leftVel * irReadResult.resolution;

      final newRightOffset = lastRightOffset + polarToCartesianRad(rotationRad, rightDistance);
      final newLeftOffset = lastLeftOffset + polarToCartesianRad(rotationRad, leftDistance);

      wheelPositions.add((lastLeftOffset, lastRightOffset));

      // IR Stuff

      double mAlpha = rotationRad + pi / 2 - atan(robiConfig.distanceWheelIr / (robiConfig.trackWidth / 2));
      double rAlpha = rotationRad + pi / 2 - atan(robiConfig.distanceWheelIr / (robiConfig.trackWidth / 2 - robiConfig.irDistance));
      double lAlpha = rotationRad + pi / 2 - atan(robiConfig.distanceWheelIr / (robiConfig.trackWidth / 2 + robiConfig.irDistance));

      Vector2 mIrPosition = lastRightOffset + Vector2(cos(mAlpha) * mc, sin(mAlpha) * mc);
      Vector2 rIrPosition = lastRightOffset + Vector2(cos(rAlpha) * rc, sin(rAlpha) * rc);
      Vector2 lIrPosition = lastRightOffset + Vector2(cos(lAlpha) * lc, sin(lAlpha) * lc);

      irData.add((IrReading(measurement.leftIr, lIrPosition), IrReading(measurement.middleIr, mIrPosition), IrReading(measurement.rightIr, rIrPosition)));

      lastRightOffset = newRightOffset;
      lastLeftOffset = newLeftOffset;
    }

    return IrCalculatorResult(irData: irData, wheelPositions: wheelPositions);
  }

  static List<Vector2>? pathApproximation(IrCalculatorResult irCalculatorResult, int minBlackLevel, double tolerance) {
    List<Vector2> blackPoints = [Vector2(0, 0)];

    for (final measurement in irCalculatorResult.irData) {
      if (measurement.$2.value < minBlackLevel) {
        blackPoints.add(measurement.$2.position);
      }
    }

    List<Vector2> simplifiedPoints = pointsToVector2(RamerDouglasPeucker.ramerDouglasPeucker(
      vectorsToPoints(blackPoints),
      pow(2, tolerance / 100) - 1,
    ));

    if (simplifiedPoints.length < 2) return null;

    return simplifiedPoints;
  }
}
