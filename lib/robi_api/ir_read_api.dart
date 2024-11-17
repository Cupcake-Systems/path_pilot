import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:path_pilot/helper/file_manager.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart';

import '../helper/geometry.dart';
import 'ir_line_approximation/ramers_douglas.dart';

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
  /// https://github.com/Cupcake-Systems/path_pilot/wiki/IR-Read-Result-Binary-File-Definition#64-bit-measurement-format
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
  /// https://github.com/Cupcake-Systems/path_pilot/wiki/IR-Read-Result-Binary-File-Definition
  factory IrReadResult.fromData(ByteBuffer data) {
    final dataLineCount = data.asByteData(2).lengthInBytes ~/ 8;

    return IrReadResult(
      resolution: data.asByteData(0, 2).getUint16(0) / 1000,
      measurements: [for (int i = 0; i < dataLineCount; ++i) Measurement.fromLine(data.asByteData(2 + i * 8, 8))],
    );
  }

  static Future<IrReadResult?> fromFile(String path, BuildContext context) async {
    final bytes = await readBytesFromFileWithWithStatusMessage(path, context);
    if (bytes == null) return null;
    try {
      return IrReadResult.fromData(bytes.buffer);
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to decode data!")));
      }
      return null;
    }
  }
}

class IrReading {
  final int value;
  final Vector2 position;

  const IrReading(this.value, this.position);

  static final IrReading zero = IrReading(0, zeroVec);
}

class IrCalculatorResult {
  final List<(IrReading left, IrReading middle, IrReading right)> irData;
  final List<(Vector2 left, Vector2 right)> wheelPositions;
  final List<LeftRightRobiState> robiStates;
  final int length;
  final LeftRightRobiState maxLeftVelocity, maxRightVelocity, maxLeftAcceleration, maxRightAcceleration;
  late final double maxVelocity = max(maxLeftVelocity.leftVelocity, maxRightVelocity.rightVelocity);

  IrCalculatorResult({
    required this.irData,
    required this.wheelPositions,
    required this.robiStates,
    required this.maxLeftAcceleration,
    required this.maxLeftVelocity,
    required this.maxRightAcceleration,
    required this.maxRightVelocity,
  }) : length = irData.length {
    assert(length == wheelPositions.length && length == wheelPositions.length);
  }
}

class IrCalculator {
  static IrCalculatorResult calculate(final IrReadResult irReadResult, final RobiConfig robiConfig) {
    final halfTrackWidth = robiConfig.trackWidth / 2;
    final piOver2 = pi / 2;

    final mc = sqrt(pow(robiConfig.distanceWheelIr, 2) + pow(halfTrackWidth, 2));
    final rc = sqrt(pow(robiConfig.distanceWheelIr, 2) + pow(halfTrackWidth - robiConfig.irDistance, 2));
    final lc = sqrt(pow(robiConfig.distanceWheelIr, 2) + pow(halfTrackWidth + robiConfig.irDistance, 2));

    Vector2 lastRightOffset = Vector2(0, -halfTrackWidth);
    Vector2 lastLeftOffset = Vector2(0, halfTrackWidth);

    double lastLeftVel = 0;
    double lastRightVel = 0;
    double rotationRad = 0;

    final int length = irReadResult.measurements.length;
    final List<(IrReading, IrReading, IrReading)> irData = List.filled(length, (IrReading.zero, IrReading.zero, IrReading.zero));
    final List<(Vector2, Vector2)> wheelPositions = List.filled(length, (zeroVec, zeroVec));
    final List<LeftRightRobiState> robiStates = List.filled(length, LeftRightRobiState.zero);
    LeftRightRobiState maxLeftVelocity = LeftRightRobiState.zero,
        maxRightVelocity = LeftRightRobiState.zero,
        maxLeftAcceleration = LeftRightRobiState.zero,
        maxRightAcceleration = LeftRightRobiState.zero;

    for (int i = 0; i < length; i++) {
      final measurement = irReadResult.measurements[i];

      final leftVel = freqToVel(measurement.motorLeftFreq, robiConfig.wheelRadius) * (measurement.leftFwd ? 1 : -1);
      final rightVel = freqToVel(measurement.motorRightFreq, robiConfig.wheelRadius) * (measurement.rightFwd ? 1 : -1);

      final angularVelocityRad = (rightVel - leftVel) / robiConfig.trackWidth;
      rotationRad += angularVelocityRad * irReadResult.resolution;

      final rightDistance = rightVel * irReadResult.resolution;
      final leftDistance = leftVel * irReadResult.resolution;

      final leftAccel = (leftVel - lastLeftVel) / irReadResult.resolution;
      final rightAccel = (rightVel - lastRightVel) / irReadResult.resolution;

      final newRightOffset = lastRightOffset + polarToCartesianRad(rotationRad, rightDistance);
      final newLeftOffset = lastLeftOffset + polarToCartesianRad(rotationRad, leftDistance);

      wheelPositions[i] = (lastLeftOffset, lastRightOffset);

      robiStates[i] = LeftRightRobiState(
        timeStamp: i * irReadResult.resolution,
        position: (lastLeftOffset + lastRightOffset) / 2,
        rotation: rotationRad * radians2Degrees,
        leftVelocity: leftVel,
        rightVelocity: rightVel,
        leftAcceleration: leftAccel,
        rightAcceleration: rightAccel,
      );

      if (maxLeftVelocity.leftVelocity < leftVel) {
        maxLeftVelocity = robiStates[i];
      }
      if (maxRightVelocity.rightVelocity < rightVel) {
        maxRightVelocity = robiStates[i];
      }
      if (maxLeftAcceleration.leftAcceleration < leftAccel) {
        maxLeftAcceleration = robiStates[i];
      }
      if (maxRightAcceleration.rightAcceleration < rightAccel) {
        maxRightAcceleration = robiStates[i];
      }

      // IR Calculations
      final double mAlpha = rotationRad + piOver2 - atan(robiConfig.distanceWheelIr / halfTrackWidth);
      final double rAlpha = rotationRad + piOver2 - atan(robiConfig.distanceWheelIr / (halfTrackWidth - robiConfig.irDistance));
      final double lAlpha = rotationRad + piOver2 - atan(robiConfig.distanceWheelIr / (halfTrackWidth + robiConfig.irDistance));

      irData[i] = (
        IrReading(measurement.leftIr, lastRightOffset + Vector2(cos(lAlpha) * lc, sin(lAlpha) * lc)),
        IrReading(measurement.middleIr, lastRightOffset + Vector2(cos(mAlpha) * mc, sin(mAlpha) * mc)),
        IrReading(measurement.rightIr, lastRightOffset + Vector2(cos(rAlpha) * rc, sin(rAlpha) * rc))
      );

      lastRightOffset = newRightOffset;
      lastLeftOffset = newLeftOffset;
      lastLeftVel = leftVel;
      lastRightVel = rightVel;
    }

    return IrCalculatorResult(
      irData: irData,
      wheelPositions: wheelPositions,
      robiStates: robiStates,
      maxLeftAcceleration: maxLeftAcceleration,
      maxLeftVelocity: maxLeftVelocity,
      maxRightAcceleration: maxRightAcceleration,
      maxRightVelocity: maxRightVelocity,
    );
  }

  static List<Vector2>? pathApproximation(IrCalculatorResult irCalculatorResult, int minBlackLevel, double tolerance) {
    List<Vector2> blackPoints = [Vector2(0, 0)];

    for (final measurement in irCalculatorResult.irData) {
      if (measurement.$2.value < minBlackLevel) {
        blackPoints.add(measurement.$2.position);
      }
    }

    List<Vector2> simplifiedPoints = RamerDouglasPeucker.ramerDouglasPeucker(
      blackPoints,
      pow(2, tolerance / 100) - 1,
    );

    if (simplifiedPoints.length < 2) return null;

    return simplifiedPoints;
  }
}

final Vector2 zeroVec = Vector2.zero();
