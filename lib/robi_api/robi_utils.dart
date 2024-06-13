import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:vector_math/vector_math.dart';

import 'robi_path_serializer.dart';

abstract class MissionInstruction {
  const MissionInstruction();

  Map<String, dynamic> toJson();
}

abstract class DriveInstruction extends MissionInstruction {
  @protected
  double _distance, _targetVelocity, _acceleration;

  double get distance => _distance;

  double get targetVelocity => _targetVelocity;

  double get acceleration => _acceleration;

  DriveInstruction(this._distance, this._targetVelocity, this._acceleration);

  @override
  Map<String, double> toJson() => {
        "distance": distance,
        "target_velocity": targetVelocity,
        "acceleration": acceleration
      };
}

class DriveForwardInstruction extends DriveInstruction {
  set distance(double value) => _distance = value;

  set targetVelocity(double value) => _targetVelocity = value;

  set acceleration(double value) => _acceleration = value;

  DriveForwardInstruction(
      super.distance, super.targetVelocity, super.acceleration);

  @override
  DriveForwardInstruction.fromJson(Map<String, dynamic> json)
      : super(
            json["distance"]!, json["target_velocity"]!, json["acceleration"]!);
}

class DriveForwardDistanceInstruction extends DriveForwardInstruction {
  DriveForwardDistanceInstruction(double distance, double initialVelocity)
      : super(distance, initialVelocity, 0.0);
}

class DriveForwardTimeInstruction extends DriveForwardInstruction {

  @protected
  double _time;

  set time(double value) {
    _time = value;
    distance = _time * _targetVelocity;
  }

  DriveForwardTimeInstruction(this._time, double initialVelocity)
      : super(initialVelocity * _time, initialVelocity, 0.0);
}

class AccelerateOverDistanceInstruction extends DriveForwardInstruction {
  @protected
  final double initialVelocity;

  @override
  set acceleration(double newAcceleration) {
    _acceleration = newAcceleration;
    _targetVelocity =
        sqrt(pow(initialVelocity, 2) + 2 * acceleration * distance);
  }

  @override
  set distance(double newDistance) {
    _distance = newDistance;
    _targetVelocity =
        sqrt(pow(initialVelocity, 2) + 2 * acceleration * distance);
  }

  AccelerateOverDistanceInstruction(
      {required this.initialVelocity,
      required double distance,
      required double acceleration})
      : super(
            distance,
            sqrt(pow(initialVelocity, 2) + 2 * acceleration * distance),
            acceleration);
}

class AccelerateOverTimeInstruction extends DriveForwardInstruction {
  @protected
  double _time, initialVelocity;

  double get time => _time;

  set time(double newTime) {
    _time = newTime;
    _targetVelocity = initialVelocity + acceleration * _time;
    _distance = initialVelocity * _time + 0.5 * acceleration * pow(_time, 2);
  }

  @override
  set acceleration(double newAcceleration) {
    _acceleration = newAcceleration;
    _targetVelocity = initialVelocity + acceleration * _time;
    _distance = initialVelocity * _time + 0.5 * acceleration * pow(_time, 2);
  }

  AccelerateOverTimeInstruction(
      this.initialVelocity, this._time, double acceleration)
      : super(initialVelocity * _time + 0.5 * acceleration * pow(_time, 2),
            initialVelocity + acceleration * _time, acceleration);
}

class TurnInstruction extends MissionInstruction {
  double turnDegree;
  bool left;
  double radius;

  TurnInstruction(this.turnDegree, this.left, this.radius);

  @override
  TurnInstruction.fromJson(Map<String, dynamic> json)
      : turnDegree = json["turn_degree"],
        left = json["left"],
        radius = json["radius"];

  @override
  Map<String, dynamic> toJson() =>
      {"turn_degree": turnDegree, "left": left, "radius": radius};
}

enum AvailableInstruction { driveInstruction, turnInstruction }

abstract class InstructionResult {
  final double managedVelocity, endRotation;
  final Vector2 endPosition;

  const InstructionResult(
      this.managedVelocity, this.endRotation, this.endPosition);
}

class DriveResult extends InstructionResult {
  final double accelerationDistance;

  const DriveResult(super.managedVelocity, super.endRotation, super.endPosition,
      this.accelerationDistance);
}

class TurnResult extends InstructionResult {
  final double turnRadius;

  TurnResult(super.managedVelocity, super.endRotation, super.endPosition,
      this.turnRadius);
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

class Simulator {
  final RobiConfig robiConfig;

  const Simulator(this.robiConfig);

  SimulationResult calculate(List<MissionInstruction> instructions) {
    List<InstructionResult> results = [];

    InstructionResult prevInstruction = startResult;

    double maxManagedVel = 0;
    double maxTargetVel = 0;

    for (final instruction in instructions) {
      InstructionResult result;
      if (instruction is DriveInstruction) {
        if (instruction.targetVelocity > maxTargetVel) {
          maxTargetVel = instruction.targetVelocity;
        }

        result = simulateDrive(prevInstruction, instruction);
      } else if (instruction is TurnInstruction) {
        result = simulateTurn(prevInstruction, instruction);
      } else {
        throw UnsupportedError("");
      }

      if (result.managedVelocity > maxManagedVel) {
        maxManagedVel = result.managedVelocity;
      }

      results.add(result);
      prevInstruction = result;
    }

    return SimulationResult(results, maxTargetVel, maxManagedVel);
  }

  DriveResult simulateDrive(
      InstructionResult prevInstruction, DriveInstruction instruction) {
    double distanceCoveredByAcceleration;

    if (instruction.acceleration > 0) {
      distanceCoveredByAcceleration = (pow(instruction.targetVelocity, 2) -
                  pow(prevInstruction.managedVelocity, 2))
              .abs() /
          (2 * instruction.acceleration);
    } else {
      distanceCoveredByAcceleration = 0;
    }

    if (distanceCoveredByAcceleration > instruction.distance) {
      distanceCoveredByAcceleration = instruction.distance;
    }

    double managedVelocity = pow(prevInstruction.managedVelocity, 2).toDouble();
    double thing = 2 * instruction.acceleration * distanceCoveredByAcceleration;

    // If decelerating (target velocity < previous managed velocity), flip the sign of 'thing'
    if (instruction.targetVelocity < prevInstruction.managedVelocity) {
      thing = -thing;
    }

    double finalVelocitySquared = managedVelocity + thing;

    // Ensure the result is non-negative before taking the square root
    if (finalVelocitySquared < 0) {
      finalVelocitySquared = 0;
    }

    managedVelocity = sqrt(finalVelocitySquared);

    double drivenDistance = distanceCoveredByAcceleration;

    if (managedVelocity > 0) {
      double timeForRemainingDistance =
          (instruction.distance - distanceCoveredByAcceleration) /
              managedVelocity;

      drivenDistance += managedVelocity * timeForRemainingDistance;
    }

    final endOfDrive = Vector2(
        prevInstruction.endPosition.x +
            cosD(prevInstruction.endRotation) * drivenDistance,
        prevInstruction.endPosition.y -
            sinD(prevInstruction.endRotation) * drivenDistance);

    return DriveResult(managedVelocity, prevInstruction.endRotation, endOfDrive,
        distanceCoveredByAcceleration);
  }

  TurnResult simulateTurn(
      InstructionResult prevInstructionResult, TurnInstruction instruction) {
    if (prevInstructionResult.managedVelocity <= 0 ||
        instruction.turnDegree <= 0) {
      return TurnResult(0, prevInstructionResult.endRotation,
          prevInstructionResult.endPosition, 0);
    }

    double radius = instruction.radius + robiConfig.trackWidth / 2;

    final innerDistance = radius * pi * instruction.turnDegree / 180;
    final outerDistance = (instruction.radius + robiConfig.trackWidth) *
        pi *
        instruction.turnDegree /
        180;

    double innerVelocity;

    if (prevInstructionResult is TurnResult) {
      innerVelocity = prevInstructionResult.managedVelocity;
    } else {
      double timeForCompletion =
          outerDistance / prevInstructionResult.managedVelocity;
      innerVelocity = innerDistance / timeForCompletion;
    }

    double rotation = prevInstructionResult.endRotation;
    double degree = instruction.turnDegree - 90;

    Vector2 center = polarToCartesian(rotation + 90, radius);
    Vector2 endOffset;
    Vector2 offset = prevInstructionResult.endPosition;

    if (instruction.left) {
      center.y *= -1;
      center += offset;
      endOffset = center +
          Vector2(cosD(rotation + degree) * radius,
              -sinD(rotation + degree) * radius);
      rotation += instruction.turnDegree;
    } else {
      center.x *= -1;
      center += offset;
      endOffset = center +
          Vector2(cosD(-rotation + degree) * radius,
              sinD(-rotation + degree) * radius);
      rotation -= instruction.turnDegree;
    }

    return TurnResult(innerVelocity, rotation, endOffset, radius);
  }
}

Vector2 polarToCartesian(double deg, double radius) =>
    Vector2(cosD(deg) * radius, sinD(deg) * radius);

double sinD(double deg) => sin(deg * (pi / 180));

double cosD(double deg) => cos(deg * (pi / 180));

class RobiConfig {
  final double wheelRadius, trackWidth;
  final String? name;

  RobiConfig(this.wheelRadius, this.trackWidth, {this.name});

  RobiConfig.fromJson(Map<String, dynamic> json)
      : wheelRadius = json["wheel_radius"],
        trackWidth = json["track_width"],
        name = json["name"];

  Map<String, dynamic> toJson() =>
      {"wheel_radius": wheelRadius, "track_width": trackWidth, "name": name};
}
