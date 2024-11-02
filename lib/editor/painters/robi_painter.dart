import 'dart:math';
import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robi_line_drawer/editor/painters/abstract_painter.dart';
import 'package:robi_line_drawer/editor/painters/simulation_painter.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:robi_line_drawer/robi_api/simulator.dart';
import 'package:vector_math/vector_math.dart' show Vector2, degrees2Radians, radians2Degrees;

class RobiPainter extends MyPainter {
  final Canvas canvas;
  final RobiState robiState;

  static late final ui.Image robiUiImage;
  static late final double s;

  static final b = Vector2(0.1045, 0.08);
  static final a = atan(b.y / b.x) * radians2Degrees;

  const RobiPainter({
    required this.canvas,
    required this.robiState,
  });

  static Future<void> init() async {
    final ByteData data = await rootBundle.load("assets/robi_illustration.webp");
    robiUiImage = await decodeImageFromList(data.buffer.asUint8List());
    s = 0.16 / robiUiImage.width;
  }

  @override
  void paint() {
    canvas.translate(robiState.position.x, -robiState.position.y);
    Vector2 o = polarToCartesian(a + robiState.rotation, b.length);

    canvas.translate(o.x, -o.y);
    canvas.rotate(degrees2Radians * (90 - robiState.rotation));

    canvas.scale(s, s);

    canvas.drawImage(robiUiImage, const Offset(0, 0), Paint()..filterQuality = FilterQuality.high);
  }
}

enum RobiStateType {
  leftRight,
  innerOuter,
}

abstract class RobiState {
  final Vector2 position;
  final double rotation;
  @protected
  final double _innerVelocity, _outerVelocity, _innerAcceleration, _outerAcceleration;

  const RobiState({
    required this.position,
    required this.rotation,
    required double innerVelocity,
    required double outerVelocity,
    required double innerAcceleration,
    required double outerAcceleration,
  })  : _innerVelocity = innerVelocity,
        _outerVelocity = outerVelocity,
        _innerAcceleration = innerAcceleration,
        _outerAcceleration = outerAcceleration;

  static final RobiState zero = InnerOuterRobiState(
    position: zeroVec,
    rotation: 0,
    innerVelocity: 0,
    outerVelocity: 0,
    innerAcceleration: 0,
    outerAcceleration: 0,
  );

  RobiState interpolate(RobiState other, double t) {
    return InnerOuterRobiState(
      position: position * (1 - t) + other.position * t,
      rotation: rotation * (1 - t) + other.rotation * t,
      innerVelocity: _innerVelocity * (1 - t) + other._innerVelocity * t,
      outerVelocity: _outerVelocity * (1 - t) + other._outerVelocity * t,
      innerAcceleration: _innerAcceleration * (1 - t) + other._innerAcceleration * t,
      outerAcceleration: _outerAcceleration * (1 - t) + other._outerAcceleration * t,
    );
  }

  LeftRightRobiState asLeftRight() {
    return LeftRightRobiState(
      position: position,
      rotation: rotation,
      leftVelocity: _innerVelocity,
      rightVelocity: _outerVelocity,
      leftAcceleration: _innerAcceleration,
      rightAcceleration: _outerAcceleration,
    );
  }

  InnerOuterRobiState asInnerOuter() {
    return InnerOuterRobiState(
      position: position,
      rotation: rotation,
      innerVelocity: _innerVelocity,
      outerVelocity: _outerVelocity,
      innerAcceleration: _innerAcceleration,
      outerAcceleration: _outerAcceleration,
    );
  }
}

class LeftRightRobiState extends RobiState {
  static RobiStateType type = RobiStateType.leftRight;
  final double leftVelocity, rightVelocity, leftAcceleration, rightAcceleration;

  LeftRightRobiState({
    required super.position,
    required super.rotation,
    required this.leftVelocity,
    required this.rightVelocity,
    required this.leftAcceleration,
    required this.rightAcceleration,
  }) : super(
          innerVelocity: leftVelocity,
          outerVelocity: rightVelocity,
          innerAcceleration: leftAcceleration,
          outerAcceleration: rightAcceleration,
        );

  static final LeftRightRobiState zero = LeftRightRobiState(
    position: zeroVec,
    rotation: 0,
    leftVelocity: 0,
    rightVelocity: 0,
    leftAcceleration: 0,
    rightAcceleration: 0,
  );
}

class InnerOuterRobiState extends RobiState {
  static RobiStateType type = RobiStateType.innerOuter;
  final double innerVelocity, outerVelocity, innerAcceleration, outerAcceleration;

  InnerOuterRobiState({
    required super.position,
    required super.rotation,
    required this.innerVelocity,
    required this.outerVelocity,
    required this.innerAcceleration,
    required this.outerAcceleration,
  }) : super(
          innerVelocity: innerVelocity,
          outerVelocity: outerVelocity,
          innerAcceleration: innerAcceleration,
          outerAcceleration: outerAcceleration,
        );
}

InnerOuterRobiState getRobiStateAtTime(List<InstructionResult> instructionResults, double t) {
  if (instructionResults.isEmpty) return RobiState.zero.asInnerOuter();

  final currentDriveResult = getRobiInstructionResultAtTime(instructionResults, t);

  final double ct = instructionResults.takeWhile((instResult) => instResult != currentDriveResult).fold(0, (sum, instResult) => sum + instResult.outerTotalTime);

  return getRobiStateAtTimeInInstructionResult(currentDriveResult!, t - ct);
}

InstructionResult? getRobiInstructionResultAtTime(List<InstructionResult> results, double t) {
  double ct = 0;
  for (final instResult in results) {
    ct += instResult.outerTotalTime;

    if (t < ct) {
      return instResult;
    }
  }

  return results.lastOrNull;
}

InnerOuterRobiState getRobiStateAtTimeInInstructionResult(InstructionResult res, double t) {
  if (res is DriveResult) {
    return getRobiStateAtTimeInDriveResult(res, t);
  }
  if (res is TurnResult) {
    return getRobiStateAtTimeInTurnResult(res, t);
  }
  if (res is RapidTurnResult) {
    return getRobiStateAtTimeInRapidTurnResult(res, t);
  }
  throw UnsupportedError("");
}

InnerOuterRobiState getRobiStateAtTimeInDriveResult(DriveResult res, double t) {
  late final double distanceTraveled, velocity, acceleration;

  if (t < res.accelerationTime) {
    acceleration = res.acceleration;
    velocity = res.acceleration * t + res.initialVelocity;
    distanceTraveled = 0.5 * res.acceleration * (t * t) + res.initialVelocity * t;
  } else if (t < res.accelerationTime + res.constantSpeedTime) {
    final dt = t - res.accelerationTime;
    acceleration = 0;
    velocity = res.maxVelocity;
    distanceTraveled = res.maxVelocity * dt + res.accelerationDistance;
  } else if (t < res.totalTime) {
    final dt = t - res.accelerationTime - res.constantSpeedTime;
    acceleration = -res.acceleration;
    velocity = res.maxVelocity - res.acceleration * dt;
    distanceTraveled = -0.5 * res.acceleration * (dt * dt) + res.maxVelocity * dt + res.accelerationDistance + res.constantSpeedDistance;
  } else {
    acceleration = 0;
    velocity = res.finalVelocity;
    distanceTraveled = res.totalDistance;
  }

  final position = res.startPosition + polarToCartesian(res.startRotation, distanceTraveled);

  return InnerOuterRobiState(
    position: position,
    rotation: res.startRotation,
    innerVelocity: velocity,
    outerVelocity: velocity,
    innerAcceleration: acceleration,
    outerAcceleration: acceleration,
  );
}

InnerOuterRobiState getRobiStateAtTimeInTurnResult(TurnResult res, double t) {
  final radius = res.medianRadius;
  double rotation = res.startRotation;
  final Vector2 cOfCircle = centerOfCircle(radius, rotation, res.left) + res.startPosition;

  late final Vector2 position;
  late final double innerVelocity, outerVelocity, innerAcceleration, outerAcceleration, degreeTraveled;

  if (t < res.outerAccelerationTime) {
    innerAcceleration = res.innerAcceleration;
    outerAcceleration = res.outerAcceleration;
    innerVelocity = res.innerAcceleration * t + res.innerInitialVelocity;
    outerVelocity = res.outerAcceleration * t + res.outerInitialVelocity;
    degreeTraveled = 0.5 * res.angularAcceleration * (t * t) + res.initialAngularVelocity * t;
  } else if (t < res.outerAccelerationTime + res.outerConstantSpeedTime) {
    final dt = t - res.outerAccelerationTime;
    innerAcceleration = outerAcceleration = 0;
    innerVelocity = res.maxInnerVelocity;
    outerVelocity = res.maxOuterVelocity;
    degreeTraveled = res.maxAngularVelocity * dt + res.accelerationDegree;
  } else if (t < res.outerTotalTime) {
    final dt = t - res.outerAccelerationTime - res.outerConstantSpeedTime;
    innerAcceleration = -res.innerAcceleration;
    outerAcceleration = -res.outerAcceleration;
    innerVelocity = res.maxInnerVelocity - res.innerAcceleration * dt;
    outerVelocity = res.maxOuterVelocity - res.outerAcceleration * dt;
    degreeTraveled = -0.5 * res.angularAcceleration * (dt * dt) + res.maxAngularVelocity * dt + res.accelerationDegree + res.constantSpeedDegree;
  } else {
    innerAcceleration = outerAcceleration = 0;
    innerVelocity = res.finalInnerVelocity;
    outerVelocity = res.finalOuterVelocity;
    degreeTraveled = res.totalTurnDegree;
  }

  if (res.left) {
    position = polarToCartesian(degreeTraveled - 90 + rotation, radius) + cOfCircle;
    rotation = degreeTraveled + res.startRotation;
  } else {
    position = polarToCartesian(90 - degreeTraveled + rotation, radius) + cOfCircle;
    rotation = res.startRotation - degreeTraveled;
  }

  return InnerOuterRobiState(
    position: position,
    rotation: rotation,
    innerVelocity: innerVelocity,
    outerVelocity: outerVelocity,
    innerAcceleration: innerAcceleration,
    outerAcceleration: outerAcceleration,
  );
}

InnerOuterRobiState getRobiStateAtTimeInRapidTurnResult(RapidTurnResult res, double t) {
  late final double degreeTraveled, velocity, acceleration, rotation;

  if (t < res.innerAccelerationTime) {
    acceleration = res.innerAcceleration;
    velocity = res.innerAcceleration * t;
    degreeTraveled = 0.5 * res.angularAcceleration * (t * t);
  } else if (t < res.innerAccelerationTime + res.innerConstantSpeedTime) {
    final dt = t - res.innerAccelerationTime;
    acceleration = 0;
    velocity = res.maxInnerVelocity;
    degreeTraveled = res.maxAngularVelocity * dt + res.accelerationDegree;
  } else if (t < res.innerTotalTime) {
    final dt = t - res.innerAccelerationTime - res.innerConstantSpeedTime;
    acceleration = -res.innerAcceleration;
    velocity = res.maxInnerVelocity - res.innerAcceleration * dt;
    degreeTraveled = -0.5 * res.angularAcceleration * (dt * dt) + res.maxAngularVelocity * dt + (res.totalTurnDegree - res.accelerationDegree);
  } else {
    acceleration = velocity = 0;
    degreeTraveled = res.totalTurnDegree;
  }

  if (res.left) {
    rotation = degreeTraveled + res.startRotation;
  } else {
    rotation = res.startRotation - degreeTraveled;
  }

  return InnerOuterRobiState(
    position: res.startPosition,
    rotation: rotation,
    innerVelocity: velocity,
    outerVelocity: velocity,
    innerAcceleration: acceleration,
    outerAcceleration: acceleration,
  );
}
