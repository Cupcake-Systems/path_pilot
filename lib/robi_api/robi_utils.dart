import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:robi_line_drawer/robi_api/exporter/exporter_instructions.dart';
import 'package:robi_line_drawer/robi_api/simulator.dart';
import 'package:vector_math/vector_math.dart';

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
  final double startRotation, endRotation, maxOuterVelocity, maxInnerVelocity, finalOuterVelocity, finalInnerVelocity, outerAcceleration, innerAcceleration;
  final Vector2 startPosition, endPosition;

  const InstructionResult({
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
  });

  ExportedMissionInstruction export();
}

class DriveResult extends InstructionResult {
  final double initialVelocity, maxVelocity, finalVelocity, acceleration, accelerationDistance, decelerationDistance, constantSpeedDistance;

  late final double totalDistance = accelerationDistance + decelerationDistance + constantSpeedDistance;
  late final double accelerationTime = _calculateAccelerationTime();
  late final double decelerationTime = _calculateDecelerationTime();
  late final double constantSpeedTime = maxVelocity > 0 ? constantSpeedDistance / maxVelocity : 0;

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

  double _calculateAccelerationTime() {
    if (acceleration == 0) return 0;
    return (-initialVelocity + sqrt(pow(initialVelocity, 2) + 2 * accelerationDistance * acceleration)) / acceleration;
  }

  double _calculateDecelerationTime() {
    if (acceleration == 0) return 0;

    double discriminant = pow(maxVelocity, 2) - 2 * decelerationDistance * acceleration;

    if (discriminant.abs() < 0.000001) discriminant = 0;

    return (sqrt(discriminant) - maxVelocity) / -acceleration;
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
  late final initialInnerVelocity = angularToLinear(initialAngularVelocity, innerRadius);
  late final initialOuterVelocity = angularToLinear(initialAngularVelocity, outerRadius);

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
          outerAcceleration: angularToLinear(angularAcceleration, innerRadius),
          innerAcceleration: angularToLinear(angularAcceleration, outerRadius),
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
      inner: ${initialInnerVelocity}m/s
      outer: ${initialOuterVelocity}m/s
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
        initialVelocity: initialOuterVelocity,
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
  final double maxTargetedVelocity;
  final double maxReachedVelocity;

  const SimulationResult(
    this.instructionResults,
    this.maxTargetedVelocity,
    this.maxReachedVelocity,
  );
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
