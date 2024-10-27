import 'dart:math';

import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart';

class Simulator {
  final RobiConfig robiConfig;

  const Simulator(this.robiConfig);

  SimulationResult calculate(List<MissionInstruction> instructions) {
    List<InstructionResult> results = [];

    InstructionResult? prevInstruction;

    double maxManagedVel = 0;
    double maxTargetVel = 0;

    for (int i = 0; i < instructions.length; i++) {
      final instruction = instructions[i];
      instructions.elementAtOrNull(i + 1);

      InstructionResult result;
      if (instruction is DriveInstruction) {
        result = simulateDrive(prevInstruction, instruction);
      } else if (instruction is TurnInstruction) {
        result = simulateTurn(prevInstruction, instruction);
      } else if (instruction is RapidTurnInstruction) {
        result = simulateRapidTurn(prevInstruction, instruction);
      } else {
        throw UnsupportedError("");
      }

      if (instruction.targetVelocity > maxTargetVel) {
        maxTargetVel = instruction.targetVelocity;
      }

      if (result.maxOuterVelocity > maxManagedVel) {
        maxManagedVel = result.maxOuterVelocity;
      }

      results.add(result);
      prevInstruction = result;
    }

    return SimulationResult(results, maxTargetVel, maxManagedVel);
  }

  DriveResult simulateDrive(InstructionResult? prevInstResult, DriveInstruction instruction) {
    final initialVelocity = (prevInstResult == null || prevInstResult.finalInnerVelocity.abs() < 0.0000001) ? 0.0 : prevInstResult.finalInnerVelocity;
    final acceleration = instruction.acceleration;

    final calcResult = calculateMotion(
      initialVelocity,
      acceleration,
      instruction.targetDistance,
      instruction.targetVelocity,
      instruction.targetFinalVelocity,
    );

    return DriveResult(
      startRotation: prevInstResult?.endRotation ?? 0,
      startPosition: prevInstResult?.endPosition ?? Vector2.zero(),
      initialVelocity: initialVelocity,
      maxVelocity: calcResult.maxVelocity,
      finalVelocity: calcResult.finalVelocity,
      acceleration: acceleration,
      accelerationDistance: calcResult.accelerationDistance,
      decelerationDistance: calcResult.decelerationDistance,
      constantSpeedDistance: calcResult.constantSpeedDistance,
    );
  }

// Refactored simulateTurn function
  TurnResult simulateTurn(InstructionResult? prevInstructionResult, TurnInstruction instruction) {
    double linearToAngular(double l) => l / robiConfig.trackWidth * (180 / pi);

    final innerRadius = instruction.innerRadius;
    final outerRadius = innerRadius + robiConfig.trackWidth;
    final k = innerRadius / outerRadius;

    final outerAcceleration = instruction.acceleration;
    final innerAcceleration = outerAcceleration * k;
    final angularAcceleration = linearToAngular(outerAcceleration - innerAcceleration);
    final initialOuterVelocity = prevInstructionResult?.finalInnerVelocity ?? 0;
    final initialInnerVelocity = initialOuterVelocity * k;
    final initialAngularVelocity = linearToAngular(initialOuterVelocity - initialInnerVelocity);
    double finalOuterVelocity = instruction.targetFinalVelocity;
    double finalInnerVelocity = finalOuterVelocity * k;
    double targetFinalAngularVelocity = linearToAngular(finalOuterVelocity - finalInnerVelocity);
    final targetOuterVelocity = instruction.targetVelocity;
    final targetInnerVelocity = targetOuterVelocity * k;
    final targetAngularVelocity = linearToAngular(targetOuterVelocity - targetInnerVelocity);

    final calcResult = calculateMotion(
      initialAngularVelocity,
      angularAcceleration,
      instruction.turnDegree,
      targetAngularVelocity,
      targetFinalAngularVelocity,
    );

    return TurnResult(
      left: instruction.left,
      startRotation: prevInstructionResult?.endRotation ?? 0,
      startPosition: prevInstructionResult?.endPosition ?? Vector2.zero(),
      innerRadius: innerRadius,
      outerRadius: outerRadius,
      accelerationDegree: calcResult.accelerationDistance,
      decelerationDegree: calcResult.decelerationDistance,
      constantSpeedDegree: calcResult.constantSpeedDistance,
      maxAngularVelocity: calcResult.maxVelocity,
      initialAngularVelocity: initialAngularVelocity,
      finalAngularVelocity: calcResult.finalVelocity,
      angularAcceleration: angularAcceleration,
    );
  }

  RapidTurnResult simulateRapidTurn(InstructionResult? prevInstructionResult, RapidTurnInstruction instruction) {
    double linearToAngular(double l) => l / (robiConfig.trackWidth * pi) * 360;

    final angularAcceleration = linearToAngular(instruction.acceleration);
    final targetMaxAngularVelocity = linearToAngular(instruction.targetVelocity);

    final calcResult = calculateMotion(0, angularAcceleration, instruction.turnDegree, targetMaxAngularVelocity, 0);

    return RapidTurnResult(
      trackWidth: robiConfig.trackWidth,
      left: instruction.left,
      startRotation: prevInstructionResult?.endRotation ?? 0,
      startPosition: prevInstructionResult?.endPosition ?? Vector2.zero(),
      maxAngularVelocity: calcResult.maxVelocity,
      accelerationDegree: calcResult.accelerationDistance,
      totalTurnDegree: instruction.turnDegree,
      angularAcceleration: angularAcceleration,
    );
  }

  CalculationResult calculateMotion(double initialVelocity, double acceleration, double targetDistance, double targetMaxVelocity, double targetFinalVelocity) {
    if (acceleration <= 0) {
      return CalculationResult(
        maxVelocity: initialVelocity,
        finalVelocity: initialVelocity,
        accelerationDistance: 0,
        decelerationDistance: 0,
        constantSpeedDistance: targetDistance,
      );
    }

    double maxVelocity, accelerationDistance, decelerationStartPoint;

    double brakePoint = (2 * acceleration * targetDistance + pow(targetFinalVelocity, 2) - pow(initialVelocity, 2)) / (4 * acceleration);
    brakePoint = min(brakePoint, targetDistance);

    final velocityAtBrakePoint = sqrt(pow(initialVelocity, 2) + (2 * acceleration * brakePoint));

    if (velocityAtBrakePoint > targetMaxVelocity) {
      maxVelocity = targetMaxVelocity;
      accelerationDistance = (pow(targetMaxVelocity, 2) - pow(initialVelocity, 2)) / (2 * acceleration);
      decelerationStartPoint = (2 * acceleration * targetDistance - pow(targetMaxVelocity, 2) + pow(targetFinalVelocity, 2)) / (2 * acceleration);
    } else {
      maxVelocity = velocityAtBrakePoint;
      accelerationDistance = brakePoint;
      decelerationStartPoint = brakePoint;
    }

    decelerationStartPoint = max(decelerationStartPoint, 0);
    accelerationDistance = max(accelerationDistance, 0);
    maxVelocity = max(maxVelocity, initialVelocity);

    double decelerationDistance = targetDistance - decelerationStartPoint;
    if (decelerationDistance.abs() < 0.000001) decelerationDistance = 0;

    double finalVelocitySqr = pow(maxVelocity, 2) - 2 * acceleration * decelerationDistance;

    if (finalVelocitySqr.abs() < 0.0000001) finalVelocitySqr = 0;

    assert(finalVelocitySqr >= 0);

    final finalVelocity = sqrt(finalVelocitySqr);

    return CalculationResult(
      maxVelocity: maxVelocity,
      finalVelocity: finalVelocity,
      accelerationDistance: accelerationDistance,
      decelerationDistance: decelerationDistance,
      constantSpeedDistance: targetDistance - accelerationDistance - decelerationDistance,
    );
  }
}

Vector2 polarToCartesian(double deg, double radius) => Vector2(cosD(deg) * radius, sinD(deg) * radius);

double sinD(double deg) => sin(deg * degrees2Radians);

double cosD(double deg) => cos(deg * degrees2Radians);

class CalculationResult {
  final double maxVelocity;
  final double finalVelocity;
  final double accelerationDistance;
  final double decelerationDistance;
  final double constantSpeedDistance;

  CalculationResult({
    required this.maxVelocity,
    required this.finalVelocity,
    required this.accelerationDistance,
    required this.decelerationDistance,
    required this.constantSpeedDistance,
  });
}
