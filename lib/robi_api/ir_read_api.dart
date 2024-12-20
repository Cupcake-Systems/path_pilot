import 'dart:math';
import 'dart:typed_data';

import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:path_pilot/helper/dialogs.dart';
import 'package:path_pilot/helper/file_manager.dart';
import 'package:path_pilot/main.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart';

import '../helper/geometry.dart';
import 'ir_line_approximation/ramers_douglas.dart';

final class Measurement {
  final int motorLeftFreq, motorRightFreq, leftIr, middleIr, rightIr;
  final bool leftFwd, rightFwd;
  final int? readingIndex;

  const Measurement({
    required this.motorLeftFreq,
    required this.motorRightFreq,
    required this.leftIr,
    required this.middleIr,
    required this.rightIr,
    required this.leftFwd,
    required this.rightFwd,
    this.readingIndex,
  });

  static const zero = Measurement(
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
  factory Measurement.fromLine(ByteData line, [int? readingIndex]) {
    final readAndFwdByte = line.getUint32(4);
    return Measurement(
      motorLeftFreq: line.getUint16(0),
      motorRightFreq: line.getUint16(2),
      leftIr: (readAndFwdByte >> 20) & 0x3FF,
      middleIr: (readAndFwdByte >> 10) & 0x3FF,
      rightIr: readAndFwdByte & 0x3FF,
      leftFwd: (readAndFwdByte & (1 << 31)) != 0,
      rightFwd: (readAndFwdByte & (1 << 30)) != 0,
      readingIndex: readingIndex,
    );
  }
}

class IrReadResult {
  final int versionNumber;
  final double resolution;
  final List<Measurement> measurements;

  double get totalTime => resolution * (measurements.length - 1);

  const IrReadResult({required this.versionNumber, required this.resolution, required this.measurements});

  /// Binary file structure documentation:
  /// https://github.com/Cupcake-Systems/path_pilot/wiki/IR-Read-Result-Binary-File-Definition
  static IrReadResult? fromDataWithStatusMessage(ByteBuffer data) {
    const versionNumberBytes = 2;
    final versionNumber = data.asByteData(0, versionNumberBytes).getUint16(0);

    switch (versionNumber) {
      case 1:
        const resolutionBytes = 2;
        const dataLineBytes = 8;
        const dataLineOffset = versionNumberBytes + resolutionBytes;

        final dataLineCount = data.asByteData(dataLineOffset).lengthInBytes ~/ dataLineBytes;

        if (dataLineCount == 0) {
          logger.warning("No data found in file");
          showSnackBar("No data found!");
          return null;
        }

        final irReadRes = IrReadResult(
          versionNumber: data.asByteData(0, versionNumberBytes).getUint16(0),
          resolution: data.asByteData(versionNumberBytes, resolutionBytes).getUint16(0) / 1000,
          measurements: [
            for (int i = 0; i < dataLineCount; ++i)
              Measurement.fromLine(
                data.asByteData(
                  dataLineOffset + i * dataLineBytes,
                  dataLineBytes,
                ),
                i,
              ),
          ],
        );

        logger.info("Successfully loaded ${irReadRes.measurements.length} measurements with resolution ${irReadRes.resolution}");

        return irReadRes;
      default:
        logger.warning("Unsupported file version: $versionNumber");
        showSnackBar("Unsupported file version: $versionNumber");
        return null;
    }
  }

  static Future<IrReadResult?> fromFileWithStatusMessage(String path) async {
    final bytes = await readBytesFromFileWithWithStatusMessage(path);
    if (bytes == null) return null;
    try {
      return IrReadResult.fromDataWithStatusMessage(bytes.buffer);
    } catch(e, s) {
      logger.errorWithStackTrace("Failed to decode data from '$path'", e, s);
      showSnackBar("Failed to decode data!");
      return null;
    }
  }

  Measurement? getMeasurementAtTime(final double t) {
    if (measurements.isEmpty) {
      return null;
    } else if (measurements.length == 1) {
      return measurements.first;
    }

    if (t <= resolution) return measurements.first;
    if (t >= totalTime) return measurements.last;

    return measurements[(t / totalTime * (measurements.length - 1)).toInt()];
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

  RobiState getStateAtTime(final IrReadResult irReadResult, final double t) {
    final totalTime = irReadResult.totalTime;
    final measurementTimeDelta = irReadResult.resolution;

    if (robiStates.isEmpty) {
      return RobiState.zero;
    } else if (robiStates.length == 1) {
      return robiStates.first;
    }

    if (t >= totalTime) return robiStates.last;

    final stateIndex = (t / totalTime * (robiStates.length - 1)).toInt();
    final state = robiStates[stateIndex];
    final timeInState = t - state.timeStamp;

    return state.interpolate(robiStates[stateIndex + 1], timeInState / measurementTimeDelta);
  }
}

class IrCalculator {
  static IrCalculatorResult calculate(final IrReadResult irReadResult, final RobiConfig robiConfig) {
    final halfTrackWidth = robiConfig.trackWidth / 2;
    final piOver2 = pi / 2;

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

      wheelPositions[i] = (lastLeftOffset, lastRightOffset);

      final robiPosition = (lastLeftOffset + lastRightOffset) / 2;

      final newRightOffset = robiPosition + polarToCartesianRad(rotationRad - piOver2, halfTrackWidth) + polarToCartesianRad(rotationRad, rightDistance);
      final newLeftOffset = robiPosition + polarToCartesianRad(rotationRad + piOver2, halfTrackWidth) + polarToCartesianRad(rotationRad, leftDistance);

      robiStates[i] = LeftRightRobiState(
        timeStamp: i * irReadResult.resolution,
        position: robiPosition,
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

      final middleIrPos = robiPosition + polarToCartesianRad(rotationRad, robiConfig.distanceWheelIr);
      final lrDelta = polarToCartesianRad(rotationRad + piOver2, robiConfig.irDistance);

      irData[i] = (
        IrReading(measurement.leftIr, middleIrPos + lrDelta),
        IrReading(measurement.middleIr, middleIrPos),
        IrReading(measurement.rightIr, middleIrPos - lrDelta),
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
      final darkestMeasurement = [measurement.$1, measurement.$2, measurement.$3].reduce((a, b) => a.value < b.value ? a : b);
      if (darkestMeasurement.value < minBlackLevel) {
        blackPoints.add(darkestMeasurement.position);
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
