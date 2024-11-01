import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:robi_line_drawer/robi_api/exporter/exporter_instructions.dart';
import 'package:robi_line_drawer/robi_api/simulator.dart';
import 'package:vector_math/vector_math.dart';

import '../main.dart';

abstract class MissionInstruction {
  double targetVelocity, acceleration, targetFinalVelocity;

  MissionInstruction({
    required this.targetVelocity,
    required this.acceleration,
    required this.targetFinalVelocity,
  }) {
    assert(targetVelocity >= 0);
    assert(acceleration >= 0);
    assert(targetFinalVelocity >= 0);
  }

  MissionInstruction.random()
      : targetVelocity = rand.nextDouble(),
        acceleration = rand.nextDouble(),
        targetFinalVelocity = rand.nextDouble();

  static MissionInstruction generateRandom() {
    final random = rand.nextInt(3);
    if (random == 0) {
      return DriveInstruction.random();
    } else if (random == 1) {
      return TurnInstruction.random();
    } else {
      return RapidTurnInstruction.random();
    }
  }

  Map<String, dynamic> toJson();
}

class DriveInstruction extends MissionInstruction {
  double targetDistance;

  DriveInstruction({
    required super.targetVelocity,
    required super.acceleration,
    required super.targetFinalVelocity,
    required this.targetDistance,
  }) {
    assert(targetDistance >= 0);
  }

  DriveInstruction.fromJson(Map<String, dynamic> json)
      : targetDistance = json["distance"],
        super(
          targetVelocity: json["target_velocity"],
          acceleration: json["acceleration"],
          targetFinalVelocity: json["end_velocity"],
        );

  DriveInstruction.random()
      : targetDistance = rand.nextDouble(),
        super.random();

  @override
  Map<String, double> toJson() => {
        "distance": targetDistance,
        "target_velocity": targetVelocity,
        "acceleration": acceleration,
        "end_velocity": targetFinalVelocity,
      };
}

class TurnInstruction extends MissionInstruction {
  double turnDegree, innerRadius;
  bool left;

  TurnInstruction({
    required this.left,
    required this.turnDegree,
    required this.innerRadius,
    required super.targetVelocity,
    required super.acceleration,
    required super.targetFinalVelocity,
  }) {
    assert(turnDegree >= 0);
  }

  TurnInstruction.random()
      : turnDegree = rand.nextDouble() * 360,
        innerRadius = rand.nextDouble(),
        left = rand.nextBool(),
        super.random();

  @override
  TurnInstruction.fromJson(Map<String, dynamic> json)
      : turnDegree = json["turn_degree"],
        innerRadius = json["inner_radius"],
        left = json["left"],
        super(
          targetVelocity: json["target_velocity"],
          acceleration: json["acceleration"],
          targetFinalVelocity: json["end_velocity"],
        );

  @override
  Map<String, dynamic> toJson() => {
        "turn_degree": turnDegree,
        "inner_radius": innerRadius,
        "target_velocity": targetVelocity,
        "acceleration": acceleration,
        "end_velocity": targetFinalVelocity,
        "left": left,
      };
}

class RapidTurnInstruction extends MissionInstruction {
  double turnDegree;
  bool left;

  RapidTurnInstruction({
    required this.left,
    required this.turnDegree,
    required super.acceleration,
    required super.targetVelocity,
  }) : super(targetFinalVelocity: 0.0) {
    assert(turnDegree > 0);
  }

  RapidTurnInstruction.random()
      : turnDegree = rand.nextDouble() * 360,
        left = rand.nextBool(),
        super.random();

  @override
  RapidTurnInstruction.fromJson(Map<String, dynamic> json)
      : turnDegree = json["turn_degree"],
        left = json["left"],
        super(
          targetVelocity: json["target_velocity"],
          acceleration: json["acceleration"],
          targetFinalVelocity: json["end_velocity"],
        );

  @override
  Map<String, dynamic> toJson() => {
        "turn_degree": turnDegree,
        "target_velocity": targetVelocity,
        "acceleration": acceleration,
        "end_velocity": targetFinalVelocity,
        "left": left,
      };
}

abstract class InstructionResult {
  final double startRotation,
      endRotation,
      maxOuterVelocity,
      maxInnerVelocity,
      finalOuterVelocity,
      finalInnerVelocity,
      outerAcceleration,
      innerAcceleration,
      innerInitialVelocity,
      outerInitialVelocity,
      innerAccelerationDistance,
      outerAccelerationDistance,
      innerConstantSpeedDistance,
      outerConstantSpeedDistance,
      innerDecelerationDistance,
      outerDecelerationDistance;
  final Vector2 startPosition, endPosition;

  late final double innerAccelerationTime = _calculateAccelerationTime(innerAcceleration, innerInitialVelocity, innerAccelerationDistance);
  late final double outerAccelerationTime = _calculateAccelerationTime(outerAcceleration, outerInitialVelocity, outerAccelerationDistance);
  late final double innerDecelerationTime = _calculateDecelerationTime(innerAcceleration, innerInitialVelocity, maxInnerVelocity, innerDecelerationDistance);
  late final double outerDecelerationTime = _calculateDecelerationTime(outerAcceleration, outerInitialVelocity, maxOuterVelocity, outerDecelerationDistance);
  late final double innerConstantSpeedTime = maxInnerVelocity > 0 ? innerConstantSpeedDistance / maxInnerVelocity : 0;
  late final double outerConstantSpeedTime = maxOuterVelocity > 0 ? outerConstantSpeedDistance / maxOuterVelocity : 0;
  late final double innerTotalTime = innerAccelerationTime + innerDecelerationTime + innerConstantSpeedTime;
  late final double outerTotalTime = outerAccelerationTime + outerDecelerationTime + outerConstantSpeedTime;
  late final double innerTotalDistance = innerAccelerationDistance + innerDecelerationDistance + innerConstantSpeedDistance;
  late final double outerTotalDistance = outerAccelerationDistance + outerDecelerationDistance + outerConstantSpeedDistance;

  double _calculateAccelerationTime(double a, double vi, double accelerationDistance) {
    if (a == 0) return 0;
    return (-vi + sqrt(pow(vi, 2) + 2 * accelerationDistance * a)) / a;
  }

  double _calculateDecelerationTime(double a, double vi, double maxVelocity, double decelerationDistance) {
    if (a == 0) return 0;

    double discriminant = pow(maxVelocity, 2) - 2 * decelerationDistance * a;

    if (discriminant.abs() < 0.000001) discriminant = 0;

    return (sqrt(discriminant) - maxVelocity) / -a;
  }

  InstructionResult({
    required this.startRotation,
    required this.endRotation,
    required this.maxOuterVelocity,
    required this.maxInnerVelocity,
    required this.finalOuterVelocity,
    required this.finalInnerVelocity,
    required this.outerAcceleration,
    required this.innerAcceleration,
    required this.startPosition,
    required this.endPosition,
    required this.innerInitialVelocity,
    required this.outerInitialVelocity,
    required this.innerAccelerationDistance,
    required this.outerAccelerationDistance,
    required this.innerConstantSpeedDistance,
    required this.outerConstantSpeedDistance,
    required this.innerDecelerationDistance,
    required this.outerDecelerationDistance,
  });

  ExportedMissionInstruction export();
}

class DriveResult extends InstructionResult {
  final double initialVelocity, maxVelocity, finalVelocity, acceleration, accelerationDistance, decelerationDistance, constantSpeedDistance;

  late final double totalDistance = innerTotalDistance;
  late final double accelerationTime = innerAccelerationTime;
  late final double decelerationTime = innerDecelerationTime;
  late final double constantSpeedTime = innerConstantSpeedTime;
  late final double totalTime = innerTotalTime;

  DriveResult({
    required super.startPosition,
    required super.startRotation,
    required this.maxVelocity,
    required this.finalVelocity,
    required this.acceleration,
    required this.initialVelocity,
    required this.constantSpeedDistance,
    required this.accelerationDistance,
    required this.decelerationDistance,
  }) : super(
          maxOuterVelocity: maxVelocity,
          maxInnerVelocity: maxVelocity,
          finalInnerVelocity: finalVelocity,
          finalOuterVelocity: finalVelocity,
          outerAcceleration: acceleration,
          innerAcceleration: acceleration,
          endRotation: startRotation,
          innerInitialVelocity: initialVelocity,
          outerInitialVelocity: initialVelocity,
          innerAccelerationDistance: accelerationDistance,
          outerAccelerationDistance: accelerationDistance,
          innerConstantSpeedDistance: constantSpeedDistance,
          outerConstantSpeedDistance: constantSpeedDistance,
          innerDecelerationDistance: decelerationDistance,
          outerDecelerationDistance: decelerationDistance,
          endPosition: startPosition +
              polarToCartesian(
                startRotation,
                accelerationDistance + decelerationDistance + constantSpeedDistance,
              ),
        ) {
    if (kDebugMode) {
      try {
        assert(maxVelocity >= 0);
        assert(finalVelocity >= 0);
        assert(acceleration >= 0);
        assert(initialVelocity >= 0);
        assert(constantSpeedDistance >= 0);
        assert(accelerationDistance >= 0);
        assert(decelerationDistance >= 0);
      } on AssertionError {
        print(this);
        rethrow;
      }
    }
  }

  @override
  String toString() {
    return '''TurnResult(
    --- Given ---
    Acceleration: ${acceleration}m/s²
    Initial Velocity: ${initialVelocity}m/s    
    --- Calculated ---
    Distance:
      Driven Distance: ${totalDistance}m
      Acceleration Distance: ${accelerationDistance}m
      Constant Speed Distance: ${constantSpeedDistance}m
      Deceleration Distance: ${decelerationDistance}m
    Time:
      Acceleration Time: ${accelerationTime}s
      Constant Speed Time: ${constantSpeedTime}s
      Deceleration Time: ${decelerationTime}s
    Max Velocity: ${maxVelocity}m/s
    Final Velocity: ${finalVelocity}m/s
)''';
  }

  @override
  ExportedDriveInstruction export() {
    assert(accelerationTime >= 0);
    assert(decelerationTime >= 0);
    assert(constantSpeedTime >= 0);

    return ExportedDriveInstruction(
      acceleration: acceleration,
      initialVelocity: initialVelocity,
      accelerationTime: accelerationTime,
      decelerationTime: decelerationTime,
      constantSpeedTime: constantSpeedTime,
    );
  }
}

class TurnResult extends InstructionResult {
  final double innerRadius, outerRadius, accelerationDegree, decelerationDegree, constantSpeedDegree, maxAngularVelocity, finalAngularVelocity, initialAngularVelocity, angularAcceleration;
  final bool left;

  late final totalTurnDegree = accelerationDegree + decelerationDegree + constantSpeedDegree;
  late final trackWidth = outerRadius - innerRadius;

  TurnResult({
    required this.left,
    required super.startRotation,
    required super.startPosition,
    required this.innerRadius,
    required this.outerRadius,
    required this.accelerationDegree,
    required this.decelerationDegree,
    required this.maxAngularVelocity,
    required this.constantSpeedDegree,
    required this.finalAngularVelocity,
    required this.initialAngularVelocity,
    required this.angularAcceleration,
  }) : super(
          endRotation: startRotation + (accelerationDegree + decelerationDegree + constantSpeedDegree) * (left ? 1 : -1),
          endPosition: _calculateEndPosition(left, (innerRadius + outerRadius) / 2, startRotation, startPosition, accelerationDegree + decelerationDegree + constantSpeedDegree),
          maxInnerVelocity: angularToLinear(maxAngularVelocity, innerRadius),
          maxOuterVelocity: angularToLinear(maxAngularVelocity, outerRadius),
          finalInnerVelocity: angularToLinear(finalAngularVelocity, innerRadius),
          finalOuterVelocity: angularToLinear(finalAngularVelocity, outerRadius),
          outerAcceleration: angularToLinear(angularAcceleration, outerRadius),
          innerAcceleration: angularToLinear(angularAcceleration, innerRadius),
          innerAccelerationDistance: angularToLinear(accelerationDegree, innerRadius),
          outerAccelerationDistance: angularToLinear(accelerationDegree, outerRadius),
          innerConstantSpeedDistance: angularToLinear(constantSpeedDegree, innerRadius),
          outerConstantSpeedDistance: angularToLinear(constantSpeedDegree, outerRadius),
          innerDecelerationDistance: angularToLinear(decelerationDegree, innerRadius),
          outerDecelerationDistance: angularToLinear(decelerationDegree, outerRadius),
          innerInitialVelocity: angularToLinear(initialAngularVelocity, innerRadius),
          outerInitialVelocity: angularToLinear(initialAngularVelocity, outerRadius),
        );

  @override
  String toString() {
    return '''TurnResult(
    left: $left
    totalTurnDegree: $totalTurnDegree°
    innerRadius: ${innerRadius}m
    Acceleration:
      Inner: ${innerAcceleration}m/s²
      Outer: ${outerAcceleration}m/s²
      Angular: $angularAcceleration°/s²
      Acceleration Degree: $accelerationDegree°
      Deceleration Degree: $decelerationDegree°
    Initial Velocity:
      inner: ${innerInitialVelocity}m/s
      outer: ${outerInitialVelocity}m/s
      angular: $initialAngularVelocity°/s
    Max Velocity:
      inner: ${maxInnerVelocity}m/s
      outer: ${maxOuterVelocity}m/s
      angular: $maxAngularVelocity°/s
    Final Velocity:
      inner: ${finalInnerVelocity}m/s
      outer: ${finalOuterVelocity}m/s
      angular: $finalAngularVelocity°/s
)''';
  }

  @override
  ExportedTurnInstruction export() => ExportedTurnInstruction(
        acceleration: outerAcceleration,
        initialVelocity: outerInitialVelocity,
        left: endRotation > startRotation,
        totalTurnDegree: totalTurnDegree.abs(),
        innerRadius: innerRadius,
        accelerationDegree: accelerationDegree.abs(),
        decelerationDegree: decelerationDegree.abs(),
      );

  static Vector2 _calculateEndPosition(bool left, double radius, double startRotation, Vector2 startPosition, double totalTurnDegree) {
    late final Vector2 center;
    if (left) {
      center = startPosition + polarToCartesian(startRotation + 90, radius);
      return center + polarToCartesian(startRotation + (270 + totalTurnDegree), radius);
    } else {
      center = startPosition + polarToCartesian(startRotation - 90, radius);
      return center + polarToCartesian(startRotation + (90 - totalTurnDegree), radius);
    }
  }

  double linearToAngular(double inner, double outer) => (outer - inner) / trackWidth * (180 / pi);
}

class RapidTurnResult extends InstructionResult {
  final double accelerationDegree, totalTurnDegree, angularAcceleration, maxAngularVelocity, trackWidth;
  final double finalAngularVelocity = 0;
  final bool left;

  RapidTurnResult({
    required this.left,
    required super.startRotation,
    required this.angularAcceleration,
    required super.startPosition,
    required this.maxAngularVelocity,
    required this.accelerationDegree,
    required this.totalTurnDegree,
    required this.trackWidth,
  }) : super(
          outerAcceleration: angularToLinear(angularAcceleration, trackWidth / 2),
          innerAcceleration: angularToLinear(angularAcceleration, trackWidth / 2),
          finalOuterVelocity: 0,
          finalInnerVelocity: 0,
          maxOuterVelocity: angularToLinear(maxAngularVelocity, trackWidth / 2),
          maxInnerVelocity: angularToLinear(maxAngularVelocity, trackWidth / 2),
          endPosition: startPosition,
          endRotation: startRotation + (totalTurnDegree * (left ? 1 : -1)),
          innerInitialVelocity: 0,
          outerInitialVelocity: 0,
          innerAccelerationDistance: angularToLinear(accelerationDegree, trackWidth / 2),
          outerAccelerationDistance: angularToLinear(accelerationDegree, trackWidth / 2),
          innerConstantSpeedDistance: angularToLinear(totalTurnDegree - accelerationDegree * 2, trackWidth / 2),
          outerConstantSpeedDistance: angularToLinear(totalTurnDegree - accelerationDegree * 2, trackWidth / 2),
          innerDecelerationDistance: angularToLinear(accelerationDegree, trackWidth / 2),
          outerDecelerationDistance: angularToLinear(accelerationDegree, trackWidth / 2),
        );

  @override
  ExportedRapidTurnInstruction export() => ExportedRapidTurnInstruction(
        acceleration: outerAcceleration,
        left: endRotation > startRotation,
        totalTurnDegree: totalTurnDegree,
        accelerationDegree: accelerationDegree,
      );

  @override
  String toString() {
    return '''TurnResult(
    Left: $left
    Total Turn Degree: $totalTurnDegree°
    Track Width: ${trackWidth}m
    Acceleration:
      Inner: ${innerAcceleration}m/s²
      Outer: ${outerAcceleration}m/s²
      Angular: $angularAcceleration°/s²
      Acceleration Degree: $accelerationDegree°
      Deceleration Degree: $accelerationDegree°
    Max Velocity:
      inner: ${maxInnerVelocity}m/s
      outer: ${maxOuterVelocity}m/s
      angular: $maxAngularVelocity°/s
    Final Velocity:
      inner: ${finalInnerVelocity}m/s
      outer: ${finalOuterVelocity}m/s
      angular: $finalAngularVelocity°/s
)''';
  }
}

class SimulationResult {
  final List<InstructionResult> instructionResults;
  final double maxTargetedVelocity, maxReachedVelocity;
  final List<TurnResult> turnResults = [];
  final List<DriveResult> driveResults = [];
  final List<RapidTurnResult> rapidTurnResults = [];

  double _totalTime = 0;
  double get totalTime => _totalTime;

  SimulationResult(
    this.instructionResults,
    this.maxTargetedVelocity,
    this.maxReachedVelocity,
  ) {
    for (final instruction in instructionResults) {
      if (instruction is TurnResult) {
        turnResults.add(instruction);
      } else if (instruction is DriveResult) {
        driveResults.add(instruction);
      } else if (instruction is RapidTurnResult) {
        rapidTurnResults.add(instruction);
      } else {
        throw Exception("Unknown instruction type");
      }
      _totalTime += instruction.outerTotalTime;
    }
  }
}

class RobiConfig {
  final double wheelRadius, trackWidth, distanceWheelIr, wheelWidth, irDistance;
  final String name;

  const RobiConfig(
    this.wheelRadius,
    this.trackWidth,
    this.distanceWheelIr,
    this.wheelWidth,
    this.irDistance,
    this.name,
  );

  RobiConfig.fromJson(Map<String, dynamic> json)
      : wheelRadius = json["wheel_radius"],
        trackWidth = json["track_width"],
        distanceWheelIr = json["distance_wheel_ir"],
        wheelWidth = json["wheel_width"],
        irDistance = json["ir_distance"],
        name = json["name"];

  Map<String, dynamic> toJson() => {
        "wheel_radius": wheelRadius,
        "track_width": trackWidth,
        "distance_wheel_ir": distanceWheelIr,
        "wheel_width": wheelWidth,
        "ir_distance": irDistance,
        "name": name,
      };
}

double freqToVel(int freq, double wheelRadius) => freq * 0.00098174 * wheelRadius;

double angularToLinear(double a, double r) => (pi * a * r) / 180;
