import 'dart:math';

import 'package:robi_line_drawer/robi_api/robi_path_serializer.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart';

class Simulator {
  final RobiConfig robiConfig;

  const Simulator(this.robiConfig);

  SimulationResult calculate(List<MissionInstruction> instructions) {
    List<InstructionResult> results = [];

    InstructionResult prevInstruction = startResult;

    double maxManagedVel = 0;
    double maxTargetVel = 0;

    for (final instruction in instructions) {
      BasicInstruction baseInstruction = instruction.basic;
      InstructionResult result;
      if (baseInstruction is BaseDriveInstruction) {
        if (baseInstruction.targetVelocity > maxTargetVel) {
          maxTargetVel = baseInstruction.targetVelocity;
        }

        result = simulateDrive(prevInstruction, baseInstruction);
      } else if (baseInstruction is BaseTurnInstruction) {
        result = simulateTurn(prevInstruction, baseInstruction);
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
      InstructionResult prevInstruction, BaseDriveInstruction instruction) {
    double distanceCoveredByAcceleration;

    if (instruction.acceleration != 0) {
      distanceCoveredByAcceleration = (pow(instruction.targetVelocity, 2) -
          pow(prevInstruction.managedVelocity, 2)) /
          (2 * instruction.acceleration);
    } else {
      distanceCoveredByAcceleration = 0;
    }

    distanceCoveredByAcceleration = distanceCoveredByAcceleration.abs();

    if (distanceCoveredByAcceleration > instruction.distance) {
      distanceCoveredByAcceleration = instruction.distance;
    }

    double managedVelocity = pow(prevInstruction.managedVelocity, 2).toDouble();
    double thing = 2 * instruction.acceleration * distanceCoveredByAcceleration;

    double finalVelocitySquared = managedVelocity + thing;

    if (finalVelocitySquared < 0) {
      finalVelocitySquared = 0;
    }

    managedVelocity = sqrt(finalVelocitySquared);

    double drivenDistance = distanceCoveredByAcceleration;

    if (managedVelocity > 0) {
      final timeForRemainingDistance =
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
      InstructionResult prevInstructionResult, BaseTurnInstruction instruction) {
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