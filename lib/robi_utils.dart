import 'dart:math';
import 'package:vector_math/vector_math.dart';

abstract class MissionInstruction {}

class DriveInstruction extends MissionInstruction {
  double distance, targetVelocity, acceleration;

  DriveInstruction(this.distance, this.targetVelocity, this.acceleration);
}

class TurnInstruction extends MissionInstruction {
  double turnDegree;
  bool left;

  TurnInstruction(this.turnDegree, this.left);
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

class Simulater {
  final RobiConfig robiConfig;

  const Simulater(this.robiConfig);

  SimulationResult calculate(List<MissionInstruction> instructions) {
    List<InstructionResult> results = [];

    InstructionResult prevInstruction = DriveResult(0, 0, Vector2.zero(), 0);

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

  InstructionResult simulateDrive(
      InstructionResult prevInstruction, DriveInstruction instruction) {
    double distanceCoveredByAcceleration = (pow(instruction.targetVelocity, 2) -
                pow(prevInstruction.managedVelocity, 2))
            .abs() /
        (2 * instruction.acceleration);

    if (distanceCoveredByAcceleration > instruction.distance) {
      distanceCoveredByAcceleration = instruction.distance;
    }

    final managedVelocity = sqrt(pow(prevInstruction.managedVelocity, 2) +
        2 * instruction.acceleration * distanceCoveredByAcceleration);

    final endOfDrive = Vector2(
        prevInstruction.endPosition.x +
            cosD(prevInstruction.endRotation) * instruction.distance,
        prevInstruction.endPosition.y -
            sinD(prevInstruction.endRotation) * instruction.distance);

    return DriveResult(managedVelocity, prevInstruction.endRotation, endOfDrive,
        distanceCoveredByAcceleration);
  }

  InstructionResult simulateTurn(
      InstructionResult prevInstructionResult, TurnInstruction instruction) {
    final outerVel = prevInstructionResult.managedVelocity * 1.2;
    final innerVel = prevInstructionResult.managedVelocity * 0.8;

    final radius =
        robiConfig.trackWidth * ((outerVel + innerVel) / (outerVel - innerVel));

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

  RobiConfig(this.wheelRadius, this.trackWidth);
}
