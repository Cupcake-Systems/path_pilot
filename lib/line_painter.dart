import 'dart:math';

import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor.dart';

abstract class InstructionResult {
  final double managedVelocity, endRotation;
  final Offset endPosition;

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

    InstructionResult prevInstruction = const DriveResult(0, 0, Offset.zero, 0);

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

    final endOfDrive = Offset(
        prevInstruction.endPosition.dx +
            cosD(prevInstruction.endRotation) * instruction.distance,
        prevInstruction.endPosition.dy -
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
    double degree = instruction.turnDegree;

    double startAngle = 360 - rotation - 90;
    double sweepAngle = degree;

    Offset center;
    Offset endOffset;
    Offset offset = prevInstructionResult.endPosition;

    if (instruction.left) {
      startAngle = -rotation + (90 - degree);
      center = offset.translate(
          cosD(rotation + 90) * radius, -sinD(rotation + 90) * radius);
      endOffset = center.translate(cosD(rotation + (degree - 90)) * radius,
          -sinD(rotation + (degree - 90)) * radius);
    } else {
      center = offset.translate(
          -cosD(rotation + 90) * radius, sinD(rotation + 90) * radius);
      endOffset = center.translate(cosD(startAngle + sweepAngle) * radius,
          sinD(startAngle + sweepAngle) * radius);
    }

    if (instruction.left) {
      rotation += instruction.turnDegree;
    } else {
      rotation -= instruction.turnDegree;
    }

    return TurnResult(prevInstructionResult.managedVelocity, rotation,
        endOffset, radius, outerVel, innerVel);
  }
}

Offset polarToCartesian(double deg, double radius) =>
    Offset(cosD(deg) * radius, sinD(deg) * radius);

double sinD(double deg) => sin(deg * (pi / 180));

double cosD(double deg) => cos(deg * (pi / 180));

class RobiConfig {
  final double wheelRadius, trackWidth;

  RobiConfig(this.wheelRadius, this.trackWidth);
}

class LinePainter extends CustomPainter {
  late SimulationResult simulationResult;
  final double scale;
  final RobiConfig robiConfig;
  static const double strokeWidth = 5;
  late Simulater simulater;

  LinePainter(
      List<MissionInstruction> instructions, this.scale, this.robiConfig) {
    simulater = Simulater(robiConfig);
    simulationResult = simulater.calculate(instructions);
  }

  @override
  void paint(Canvas canvas, Size size) {
    InstructionResult prevResult = const DriveResult(0, 0, Offset.zero, 0);

    for (InstructionResult result in simulationResult.instructionResults) {
      if (result is DriveResult) {
        drawDrive(prevResult, result, canvas);
      } else if (result is TurnResult) {
        drawTurn(prevResult, result, canvas);
      }

      prevResult = result;
    }
  }

  void drawDrive(InstructionResult prevInstructionResult,
      DriveResult instructionResult, Canvas canvas) {
    List<Color> colors = [
      velocityToColor(prevInstructionResult.managedVelocity),
      velocityToColor(instructionResult.managedVelocity)
    ];

    final accelerationPaint = Paint()
      ..shader = RadialGradient(
        colors: colors,
        radius: 0.5 * (1 / sqrt2),
      ).createShader(Rect.fromCircle(
          center: prevInstructionResult.endPosition * scale,
          radius: instructionResult.accelerationDistance * scale))
      ..strokeWidth = strokeWidth;

    canvas.drawLine(prevInstructionResult.endPosition * scale,
        instructionResult.endPosition * scale, accelerationPaint);
  }

  void drawTurn(InstructionResult prevInstructionResult, TurnResult instruction,
      Canvas canvas) {
    final paint = Paint()
      ..color = velocityToColor(prevInstructionResult.managedVelocity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final degree =
        (prevInstructionResult.endRotation - instruction.endRotation).abs();
    final left = prevInstructionResult.endRotation < instruction.endRotation;

    final path = drawCirclePart(
        instruction.turnRadius,
        degree,
        prevInstructionResult.endRotation,
        prevInstructionResult.endPosition * scale,
        left);
    canvas.drawPath(path, paint);
  }

  Path drawCirclePart(
      double radius, double degree, double rotation, Offset offset, bool left) {
    radius *= scale;

    double startAngle = 360 - rotation - 90;
    double sweepAngle = degree;

    Offset center;

    if (left) {
      startAngle = -rotation + (90 - degree);
      center = offset.translate(
          cosD(rotation + 90) * radius, -sinD(rotation + 90) * radius);
    } else {
      center = offset.translate(
          -cosD(rotation + 90) * radius, sinD(rotation + 90) * radius);
    }

    return Path()
      ..arcTo(Rect.fromCircle(center: center, radius: radius),
          startAngle * (pi / 180), sweepAngle * (pi / 180), false);
  }

  Color velocityToColor(double velocity) {
    int r = (velocity / simulationResult.maxTargetedVelocity * 255).round();
    int g = 255 - r;
    return Color.fromARGB(255, r, g, 0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
