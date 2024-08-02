import 'dart:math';
import 'package:vector_math/vector_math.dart';

abstract class Serializable {
  Map<String, dynamic> toJson();
}

abstract class BasicInstruction extends Serializable {}

abstract class MissionInstruction {
  BasicInstruction get basic;

  Map<String, dynamic> toJson();
}

class BaseTurnInstruction extends BasicInstruction {
  double turnDegree, radius;
  bool left;

  BaseTurnInstruction(this.turnDegree, this.left, this.radius);

  @override
  BaseTurnInstruction.fromJson(Map<String, dynamic> json)
      : this(json["turn_degree"], json["left"], json["radius"]);

  @override
  Map<String, dynamic> toJson() =>
      {"turn_degree": turnDegree, "left": left, "radius": radius};
}

class BaseDriveInstruction extends BasicInstruction {
  double distance, targetVelocity, acceleration;

  BaseDriveInstruction(this.distance, this.targetVelocity, this.acceleration);

  @override
  Map<String, dynamic> toJson() => {
        "distance": distance,
        "target_velocity": targetVelocity,
        "acceleration": acceleration
      };
}

class DriveInstruction extends MissionInstruction {
  double distance, targetVelocity, acceleration;

  DriveInstruction(
      {required this.distance,
      required this.targetVelocity,
      required this.acceleration});

  DriveInstruction.fromJson(Map<String, dynamic> json)
      : distance = json["distance"],
        targetVelocity = json["target_velocity"],
        acceleration = json["acceleration"];

  @override
  Map<String, dynamic> toJson() => {
        "distance": distance,
        "target_velocity": targetVelocity,
        "acceleration": acceleration
      };

  @override
  BasicInstruction get basic =>
      BaseDriveInstruction(distance, targetVelocity, acceleration);
}

class DriveForwardDistanceInstruction extends MissionInstruction {
  double distance, initialVelocity;

  DriveForwardDistanceInstruction(
      {required this.distance, required this.initialVelocity});

  DriveForwardDistanceInstruction.fromJson(Map<String, dynamic> json)
      : distance = json["distance"],
        initialVelocity = json["initial_velocity"];

  @override
  Map<String, double> toJson() =>
      {"distance": distance, "initial_velocity": initialVelocity};

  @override
  BasicInstruction get basic =>
      BaseDriveInstruction(distance, initialVelocity, 0);
}

class DriveForwardTimeInstruction extends MissionInstruction {
  double time, initialVelocity;

  DriveForwardTimeInstruction(
      {required this.time, required this.initialVelocity});

  DriveForwardTimeInstruction.fromJson(Map<String, dynamic> json)
      : time = json["time"],
        initialVelocity = json["initial_velocity"];

  @override
  Map<String, double> toJson() =>
      {"time": time, "initial_velocity": initialVelocity};

  @override
  BasicInstruction get basic =>
      BaseDriveInstruction(time * initialVelocity, initialVelocity, 0);
}

class AccelerateOverDistanceInstruction extends MissionInstruction {
  double distance, initialVelocity, acceleration;

  static double _calculateFinalVelocity(
      double initialVelocity, double distance, double acceleration) {
    double finalVelocitySquared =
        pow(initialVelocity, 2) + 2 * acceleration * distance;
    return sqrt(finalVelocitySquared < 0 ? 0 : finalVelocitySquared);
  }

  AccelerateOverDistanceInstruction({
    required this.distance,
    required this.initialVelocity,
    required this.acceleration,
  });

  AccelerateOverDistanceInstruction.fromJson(Map<String, dynamic> json)
      : initialVelocity = json["initial_velocity"],
        distance = json["distance"],
        acceleration = json["acceleration"];

  @override
  Map<String, dynamic> toJson() => {
        "initial_velocity": initialVelocity,
        "distance": distance,
        "acceleration": acceleration,
      };

  @override
  BasicInstruction get basic => BaseDriveInstruction(
        distance,
        _calculateFinalVelocity(initialVelocity, distance, acceleration),
        acceleration,
      );
}

class AccelerateOverTimeInstruction extends MissionInstruction {
  double time, initialVelocity, acceleration;

  AccelerateOverTimeInstruction({
    required this.time,
    required this.initialVelocity,
    required this.acceleration,
  });

  AccelerateOverTimeInstruction.fromJson(Map<String, dynamic> json)
      : initialVelocity = json["initial_velocity"],
        time = json["time"],
        acceleration = json["acceleration"];

  @override
  Map<String, dynamic> toJson() => {
        "initial_velocity": initialVelocity,
        "time": time,
        "acceleration": acceleration
      };

  @override
  BasicInstruction get basic => BaseDriveInstruction(
      calculateDistance(time, initialVelocity, acceleration),
      calculateFinalVelocity(initialVelocity, time, acceleration),
      acceleration);

  static double calculateFinalVelocity(
      double initialVelocity, double time, double acceleration) {
    double finalVelocity = initialVelocity + acceleration * time;
    return finalVelocity > 0 ? finalVelocity : 0;
  }

  static double calculateDistance(
      double time, double initialVelocity, double acceleration) {
    double distance =
        initialVelocity * time + 0.5 * acceleration * pow(time, 2);
    return distance > 0 ? distance : initialVelocity * time;
  }
}

class StopOverTimeInstruction extends MissionInstruction {
  double time, initialVelocity;

  StopOverTimeInstruction({
    required this.time,
    required this.initialVelocity,
  });

  StopOverTimeInstruction.fromJson(Map<String, dynamic> json)
      : initialVelocity = json["initial_velocity"],
        time = json["time"];

  @override
  BasicInstruction get basic => BaseDriveInstruction(
        AccelerateOverTimeInstruction.calculateDistance(
            time, initialVelocity, -initialVelocity / time),
        0,
        -initialVelocity / time,
      );

  @override
  Map<String, dynamic> toJson() => {
        "initial_velocity": initialVelocity,
        "time": time,
      };
}

class TurnInstruction extends MissionInstruction {
  double turnDegree, radius;
  bool left;

  TurnInstruction(this.turnDegree, this.left, this.radius);

  @override
  TurnInstruction.fromJson(Map<String, dynamic> json)
      : this(json["turn_degree"], json["left"], json["radius"]);

  @override
  Map<String, dynamic> toJson() =>
      {"turn_degree": turnDegree, "left": left, "radius": radius};

  @override
  BasicInstruction get basic => BaseTurnInstruction(turnDegree, left, radius);
}

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
