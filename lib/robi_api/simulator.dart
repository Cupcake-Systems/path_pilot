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

    for (int i = 0; i < instructions.length; i++) {
      final instruction = instructions[i];
      instructions.elementAtOrNull(i + 1);

      BasicInstruction baseInstruction = instruction.basic;
      InstructionResult result;
      if (baseInstruction is BaseDriveInstruction) {
        if (baseInstruction.targetVelocity > maxTargetVel) {
          maxTargetVel = baseInstruction.targetVelocity;
        }

        result = simulateDrive(prevInstruction, baseInstruction);
      } else if (baseInstruction is BaseTurnInstruction) {
        result = simulateTurn(prevInstruction, baseInstruction);
      } else if (baseInstruction is BaseRapidTurnInstruction) {
        result = simulateRapidTurn(prevInstruction, baseInstruction);
      } else {
        throw UnsupportedError("");
      }

      if (result.maxVelocity > maxManagedVel) {
        maxManagedVel = result.maxVelocity;
      }

      results.add(result);
      prevInstruction = result;
    }

    return SimulationResult(results, maxTargetVel, maxManagedVel);
  }

  DriveResult simulateDrive(
      InstructionResult prevInstResult, BaseDriveInstruction instruction) {
    final startPosition = prevInstResult.endPosition;
    final rotation = prevInstResult.endRotation;
    final initialVelocity = prevInstResult.finalVelocity;
    final endPosition = startPosition +
        polarToCartesian(prevInstResult.endRotation, instruction.distance);
    final acceleration = instruction.acceleration;
    final targetMaxVelocity = instruction.targetVelocity;
    final endVelocity = instruction.endVelocity;

    double maxVelocity, accelerationEndPoint, decelerationStartPoint;

    assert(acceleration != 0);

    final brakePoint =
        ((2 * acceleration * instruction.distance - pow(endVelocity, 2)) -
                pow(initialVelocity, 2)) /
            (2 * acceleration);
    final velocityAtBrakePoint =
        sqrt(pow(initialVelocity, 2) + (2 * acceleration * brakePoint));

    if (velocityAtBrakePoint > targetMaxVelocity) {
      maxVelocity = targetMaxVelocity;
      accelerationEndPoint =
          (pow(targetMaxVelocity, 2) - pow(initialVelocity, 2)) /
              (2 * acceleration);
      decelerationStartPoint = (2 * acceleration * instruction.distance -
              pow(targetMaxVelocity, 2) +
              pow(endVelocity, 2)) /
          (2 * acceleration);
    } else {
      maxVelocity = velocityAtBrakePoint;
      accelerationEndPoint = brakePoint;
      decelerationStartPoint = brakePoint;
    }

    return DriveResult(
      startRotation: rotation,
      endRotation: rotation,
      startPosition: prevInstResult.endPosition,
      endPosition: endPosition,
      initialVelocity: initialVelocity,
      maxVelocity: maxVelocity,
      finalVelocity: endVelocity,
      accelerationEndPoint:
          polarToCartesian(rotation, accelerationEndPoint) + startPosition,
      decelerationStartPoint:
          polarToCartesian(rotation, decelerationStartPoint) + startPosition,
    );
  }

  TurnResult simulateTurn(InstructionResult prevInstructionResult,
      BaseTurnInstruction instruction) {
    final radius = instruction.innerRadius + robiConfig.trackWidth / 2;
    final startPosition = prevInstructionResult.endPosition;
    final startRotation = prevInstructionResult.endRotation;
    final endRotation = startRotation + instruction.turnDegree;

    final innerDistance =
        instruction.innerRadius * pi * instruction.turnDegree / 180;
    final outerDistance = (instruction.innerRadius + robiConfig.trackWidth) *
        pi *
        instruction.turnDegree /
        180;

    final timeForCompletion =
        outerDistance / prevInstructionResult.finalVelocity;
    final innerVelocity = innerDistance / timeForCompletion;

    late final Vector2 center, endPosition;

    if (instruction.turnDegree > 0) {
      center = startPosition + polarToCartesian(startRotation + 90, radius);
      endPosition = center +
          polarToCartesian(
              startRotation + (270 + instruction.turnDegree), radius);
    } else {
      center = startPosition + polarToCartesian(startRotation - 90, radius);
      endPosition = center +
          polarToCartesian(
              startRotation + (90 - instruction.turnDegree.abs()), radius);
    }

    return TurnResult(
      startRotation: startRotation,
      endRotation: endRotation,
      startPosition: startPosition,
      endPosition: endPosition,
      initialVelocity: prevInstructionResult.finalVelocity,
      maxVelocity: prevInstructionResult.finalVelocity,
      finalVelocity: innerVelocity,
      turnRadius: radius,
    );
  }

  RapidTurnResult simulateRapidTurn(InstructionResult prevInstructionResult,
      BaseRapidTurnInstruction instruction) {
    return RapidTurnResult(
      startRotation: prevInstructionResult.endRotation,
      endRotation:
          prevInstructionResult.endRotation + instruction.turnDegree,
      startPosition: prevInstructionResult.endPosition,
      endPosition: prevInstructionResult.endPosition,
      initialVelocity: 0,
      maxVelocity: 0,
      finalVelocity: 0,
    );
  }
}

Vector2 polarToCartesian(double deg, double radius) =>
    Vector2(cosD(deg), sinD(deg)) * radius;

double sinD(double deg) => sin(deg * (pi / 180));

double cosD(double deg) => cos(deg * (pi / 180));
