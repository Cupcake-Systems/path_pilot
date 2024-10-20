import 'dart:math';
import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robi_line_drawer/editor/painters/abstract_painter.dart';
import 'package:robi_line_drawer/editor/painters/simulation_painter.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:robi_line_drawer/robi_api/simulator.dart';
import 'package:vector_math/vector_math.dart' show Vector2, degrees2Radians, radians2Degrees;

class RobiPainter extends MyPainter {
  final Canvas canvas;
  final SimulationResult simulationResult;
  final double t;

  static late final ui.Image robiUiImage;
  static late final double s;

  RobiPainter({
    required this.canvas,
    required this.simulationResult,
    required this.t,
  });

  static Future<void> init() async {
    final ByteData data = await rootBundle.load("assets/robi_illustration.webp");
    robiUiImage = await decodeImageFromList(data.buffer.asUint8List());
    s = 0.16 / robiUiImage.width;
  }

  @override
  void paint() {
    final (position, rotation) = getPositionAndRotationAtTime(simulationResult, t);

    canvas.translate(position.x, -position.y);

    final b = Vector2(0.1045, 0.08);
    final a = atan(b.y / b.x) * radians2Degrees;
    Vector2 o = polarToCartesian(a + rotation, b.length);

    canvas.translate(o.x, -o.y);
    canvas.rotate(degrees2Radians * (90 - rotation));

    canvas.scale(s, s);

    canvas.drawImage(robiUiImage, const Offset(0, 0), Paint()..filterQuality = FilterQuality.high);
  }
}

(Vector2 position, double rotation) getPositionAndRotationAtTime(SimulationResult simulationResult, double t) {
  InstructionResult? currentDriveResult = simulationResult.instructionResults.lastOrNull;

  double ct = 0;
  for (final instResult in simulationResult.instructionResults) {
    if (t < ct + instResult.outerTotalTime) {
      currentDriveResult = instResult;
      break;
    }

    ct += instResult.outerTotalTime;
  }

  if (currentDriveResult == null) return (Vector2.zero(), 0);

  ct = simulationResult.instructionResults.takeWhile((instResult) => instResult != currentDriveResult).fold(0, (sum, instResult) => sum + instResult.outerTotalTime);

  double rotation = 0;
  Vector2 position;

  final res = currentDriveResult;

  rotation = res.startRotation;

  final dct = t - ct;

  if (res is DriveResult) {
    double distanceTraveled;

    if (dct < res.accelerationTime) {
      final dt = dct;
      distanceTraveled = 0.5 * res.acceleration * (dt * dt) + res.initialVelocity * dt;
    } else if (dct < res.accelerationTime + res.constantSpeedTime) {
      final dt = t - res.accelerationTime - ct;
      distanceTraveled = res.maxVelocity * dt + res.accelerationDistance;
    } else if (dct < res.totalTime) {
      final dt = t - res.accelerationTime - res.constantSpeedTime - ct;
      distanceTraveled = -0.5 * res.acceleration * (dt * dt) + res.maxVelocity * dt + res.accelerationDistance + res.constantSpeedDistance;
    } else {
      distanceTraveled = res.totalDistance;
    }

    position = currentDriveResult.startPosition + polarToCartesian(res.startRotation, distanceTraveled);
  } else if (res is TurnResult) {
    double radius = (res.innerRadius + res.outerRadius) / 2;

    Vector2 cOfCircle = centerOfCircle(radius, rotation, res.left) + res.startPosition;
    double degreeTraveled;

    if (dct < res.outerAccelerationTime) {
      final dt = dct;
      degreeTraveled = 0.5 * res.angularAcceleration * (dt * dt) + res.initialAngularVelocity * dt;
    } else if (dct < res.outerAccelerationTime + res.outerConstantSpeedTime) {
      final dt = t - res.outerAccelerationTime - ct;
      degreeTraveled = res.maxAngularVelocity * dt + res.accelerationDegree;
    } else if (dct < res.outerTotalTime) {
      final dt = t - res.outerAccelerationTime - res.outerConstantSpeedTime - ct;
      degreeTraveled = -0.5 * res.angularAcceleration * (dt * dt) + res.maxAngularVelocity * dt + res.accelerationDegree + res.constantSpeedDegree;
    } else {
      degreeTraveled = res.totalTurnDegree;
    }

    if (res.left) {
      position = polarToCartesian(degreeTraveled - 90 + rotation, radius) + cOfCircle;
      rotation = degreeTraveled + res.startRotation;
    } else {
      position = polarToCartesian(90 - degreeTraveled + rotation, radius) + cOfCircle;
      rotation = res.startRotation - degreeTraveled;
    }
  } else if (res is RapidTurnResult) {
    double degreeTraveled;

    if (dct < res.innerAccelerationTime) {
      final dt = dct;
      degreeTraveled = 0.5 * res.angularAcceleration * (dt * dt);
    } else if (dct < res.innerAccelerationTime + res.innerConstantSpeedTime) {
      final dt = t - res.innerAccelerationTime - ct;
      degreeTraveled = res.maxAngularVelocity * dt + res.accelerationDegree;
    } else if (dct < res.innerTotalTime) {
      final dt = t - res.innerAccelerationTime - res.innerConstantSpeedTime - ct;
      degreeTraveled = -0.5 * res.angularAcceleration * (dt * dt) + res.maxAngularVelocity * dt + (res.totalTurnDegree - res.accelerationDegree);
    } else {
      degreeTraveled = res.totalTurnDegree;
    }

    if (res.left) {
      rotation = degreeTraveled + res.startRotation;
    } else {
      rotation = res.startRotation - degreeTraveled;
    }

    position = res.startPosition;
  } else {
    throw UnsupportedError("");
  }

  return (position, rotation);
}
