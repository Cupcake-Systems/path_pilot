import 'dart:math';
import 'package:vector_math/vector_math.dart';

import 'robi_path_serializer.dart';

abstract class MissionInstruction {
  const MissionInstruction();

  MissionInstruction.fromJson(Map<String, dynamic> json);

  Map<String, dynamic> toJson();
}

class DriveInstruction extends MissionInstruction {
  double distance, targetVelocity, acceleration;

  DriveInstruction(this.distance, this.targetVelocity, this.acceleration);

  @override
  DriveInstruction.fromJson(Map<String, dynamic> json)
      : distance = json["distance"]!,
        targetVelocity = json["target_velocity"]!,
        acceleration = json["acceleration"]!;

  @override
  Map<String, double> toJson() => {
        "distance": distance,
        "target_velocity": targetVelocity,
        "acceleration": acceleration
      };
}

class TurnInstruction extends MissionInstruction {
  double turnDegree;
  bool left;

  TurnInstruction(this.turnDegree, this.left);

  @override
  TurnInstruction.fromJson(Map<String, dynamic> json)
      : turnDegree = json["turn_degree"]!,
        left = json["turn_degree"]!;

  @override
  Map<String, dynamic> toJson() => {
        "turn_degree": turnDegree,
        "left": left,
      };
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
  final double turnRadius, outerVelocity, innerVelocity;

  TurnResult(super.managedVelocity, super.endRotation, super.endPosition,
      this.turnRadius, this.outerVelocity, this.innerVelocity);
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
    double distanceCoveredByAcceleration = (pow(instruction.targetVelocity, 2) -
                pow(prevInstruction.managedVelocity, 2))
            .abs() /
        (2 * instruction.acceleration);

    if (distanceCoveredByAcceleration > instruction.distance) {
      distanceCoveredByAcceleration = instruction.distance;
    }

    double managedVelocity = pow(prevInstruction.managedVelocity, 2).toDouble();
    double thing = 2 * instruction.acceleration * distanceCoveredByAcceleration;
    if (instruction.targetVelocity < prevInstruction.managedVelocity) {
      thing *= -1;
    }

    managedVelocity = sqrt(managedVelocity + thing);

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
    if (prevInstructionResult.managedVelocity <= 0) {
      return TurnResult(0, prevInstructionResult.endRotation,
          prevInstructionResult.endPosition, 0, 0, 0);
    }

    final outerVel = prevInstructionResult.managedVelocity * 1.2;
    final innerVel = prevInstructionResult.managedVelocity * 0.8;

    final radius = robiConfig.trackWidth /
        2 *
        ((outerVel + innerVel) / (outerVel - innerVel));
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

    return TurnResult(prevInstructionResult.managedVelocity, rotation,
        endOffset, radius, outerVel, innerVel);
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
