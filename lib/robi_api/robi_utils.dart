import 'package:vector_math/vector_math.dart';

abstract class Serializable {
  Map<String, dynamic> toJson();
}

abstract class BasicInstruction extends Serializable {
  final double targetVelocity, endVelocity, acceleration;

  BasicInstruction({
    required this.targetVelocity,
    required this.endVelocity,
    required this.acceleration,
  });
}

abstract class MissionInstruction {
  double targetVelocity, acceleration, endVelocity;

  MissionInstruction({
    required this.targetVelocity,
    required this.acceleration,
    required this.endVelocity,
  });

  BasicInstruction get basic;

  Map<String, dynamic> toJson();
}

class BaseTurnInstruction extends BasicInstruction {
  final double turnDegree, innerRadius;

  BaseTurnInstruction({
    required super.targetVelocity,
    required super.endVelocity,
    required super.acceleration,
    required this.turnDegree,
    required this.innerRadius,
  });

  @override
  BaseTurnInstruction.fromJson(Map<String, dynamic> json)
      : turnDegree = json["turn_degree"],
        innerRadius = json["radius"],
        super(
          endVelocity: json["end_velocity"],
          acceleration: json["acceleration"],
          targetVelocity: json["target_velocity"],
        );

  @override
  Map<String, dynamic> toJson() => {
        "turn_degree": turnDegree,
        "radius": innerRadius,
        "end_velocity": endVelocity,
        "acceleration": acceleration,
        "target_velocity": targetVelocity,
      };
}

class BaseRapidTurnInstruction extends BasicInstruction {
  final double turnDegree;

  BaseRapidTurnInstruction({
    required super.targetVelocity,
    required super.endVelocity,
    required super.acceleration,
    required this.turnDegree,
  });

  @override
  BaseRapidTurnInstruction.fromJson(Map<String, dynamic> json)
      : turnDegree = json["turn_degree"],
        super(
          endVelocity: json["end_velocity"],
          acceleration: json["acceleration"],
          targetVelocity: json["target_velocity"],
        );

  @override
  Map<String, dynamic> toJson() => {
        "turn_degree": turnDegree,
        "end_velocity": endVelocity,
        "acceleration": acceleration,
        "target_velocity": targetVelocity,
      };
}

class BaseDriveInstruction extends BasicInstruction {
  final double distance;

  BaseDriveInstruction({
    required super.targetVelocity,
    required super.endVelocity,
    required super.acceleration,
    required this.distance,
  });

  @override
  BaseDriveInstruction.fromJson(Map<String, dynamic> json)
      : distance = json["distance"],
        super(
          endVelocity: json["end_velocity"],
          acceleration: json["acceleration"],
          targetVelocity: json["target_velocity"],
        );

  @override
  Map<String, dynamic> toJson() => {
        "distance": distance,
        "target_velocity": targetVelocity,
        "acceleration": acceleration,
        "end_velocity": endVelocity,
      };
}

class DriveInstruction extends MissionInstruction {
  double distance;

  DriveInstruction({
    required super.targetVelocity,
    required super.acceleration,
    required super.endVelocity,
    required this.distance,
  });

  DriveInstruction.fromJson(Map<String, dynamic> json)
      : distance = json["distance"],
        super(
          targetVelocity: json["target_velocity"],
          acceleration: json["acceleration"],
          endVelocity: json["end_velocity"],
        );

  @override
  Map<String, double> toJson() => {
        "distance": distance,
        "target_velocity": targetVelocity,
        "acceleration": acceleration,
        "end_velocity": endVelocity,
      };

  @override
  BasicInstruction get basic => BaseDriveInstruction(
        targetVelocity: targetVelocity,
        endVelocity: endVelocity,
        acceleration: acceleration,
        distance: distance,
      );
}

class TurnInstruction extends MissionInstruction {
  double turnDegree, innerRadius;

  TurnInstruction({
    required this.turnDegree,
    required this.innerRadius,
    required super.targetVelocity,
    required super.acceleration,
    required super.endVelocity,
  });

  @override
  TurnInstruction.fromJson(Map<String, dynamic> json)
      : turnDegree = json["turn_degree"],
        innerRadius = json["inner_radius"],
        super(
          targetVelocity: json["target_velocity"],
          acceleration: json["acceleration"],
          endVelocity: json["end_velocity"],
        );

  @override
  Map<String, dynamic> toJson() => {
        "turn_degree": turnDegree,
        "inner_radius": innerRadius,
        "target_velocity": targetVelocity,
        "acceleration": acceleration,
        "end_velocity": endVelocity,
      };

  @override
  BasicInstruction get basic => BaseTurnInstruction(
        targetVelocity: targetVelocity,
        endVelocity: endVelocity,
        acceleration: acceleration,
        turnDegree: turnDegree,
        innerRadius: innerRadius,
      );
}

class RapidTurnInstruction extends MissionInstruction {
  double turnDegree;

  RapidTurnInstruction({required this.turnDegree})
      : super(
          targetVelocity: 0.0,
          acceleration: 0.0,
          endVelocity: 0.0,
        );

  @override
  RapidTurnInstruction.fromJson(Map<String, dynamic> json)
      : turnDegree = json["turn_degree"],
        super(
          targetVelocity: json["target_velocity"],
          acceleration: json["acceleration"],
          endVelocity: json["end_velocity"],
        );

  @override
  Map<String, dynamic> toJson() => {
        "turn_degree": turnDegree,
        "target_velocity": targetVelocity,
        "acceleration": acceleration,
        "end_velocity": endVelocity,
      };

  @override
  BasicInstruction get basic => BaseRapidTurnInstruction(
      targetVelocity: targetVelocity,
      endVelocity: 0,
      acceleration: acceleration,
      turnDegree: turnDegree);
}

abstract class InstructionResult {
  final double startRotation,
      endRotation,
      initialVelocity,
      maxVelocity,
      finalVelocity;
  final Vector2 startPosition, endPosition;

  InstructionResult({
    required this.startRotation,
    required this.endRotation,
    required this.startPosition,
    required this.endPosition,
    required this.initialVelocity,
    required this.maxVelocity,
    required this.finalVelocity
  });
}

class DriveResult extends InstructionResult {
  final Vector2 accelerationEndPoint, decelerationStartPoint;

  DriveResult({
    required super.startRotation,
    required super.endRotation,
    required super.startPosition,
    required super.endPosition,
    required super.initialVelocity,
    required super.maxVelocity,
    required super.finalVelocity,
    required this.accelerationEndPoint,
    required this.decelerationStartPoint,
  });
}

class TurnResult extends InstructionResult {
  final double turnRadius;

  TurnResult({
    required super.startRotation,
    required super.endRotation,
    required super.startPosition,
    required super.endPosition,
    required super.initialVelocity,
    required super.maxVelocity,
    required super.finalVelocity,
    required this.turnRadius,
  });
}

class RapidTurnResult extends InstructionResult {
  RapidTurnResult({
    required super.startRotation,
    required super.endRotation,
    required super.startPosition,
    required super.endPosition,
    required super.initialVelocity,
    required super.maxVelocity,
    required super.finalVelocity,
  });
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
  final double wheelRadius, trackWidth, distanceWheelIr, wheelWidth;
  final String? name;

  RobiConfig(
      this.wheelRadius, this.trackWidth, this.distanceWheelIr, this.wheelWidth,
      {this.name});

  RobiConfig.fromJson(Map<String, dynamic> json)
      : wheelRadius = json["wheel_radius"],
        trackWidth = json["track_width"],
        distanceWheelIr = json["distance_wheel_ir"],
        wheelWidth = json["wheel_width"],
        name = json["name"];

  Map<String, dynamic> toJson() => {
        "wheel_radius": wheelRadius,
        "track_width": trackWidth,
        "distance_wheel_ir": distanceWheelIr,
        "wheel_width": wheelWidth,
        "name": name
      };
}

double freqToVel(int freq, double wheelRadius) =>
    freq * 0.00098174 * wheelRadius;
