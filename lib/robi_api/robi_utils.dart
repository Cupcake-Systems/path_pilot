import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:vector_math/vector_math.dart';

abstract class Serializable {
  Map<String, dynamic> toJson();

  Map<String, dynamic> export();
}

abstract class MissionInstruction extends Serializable {}

abstract class DriveInstruction extends MissionInstruction {
  @protected
  double _distance, _targetVelocity, _acceleration;

  double get distance => _distance;

  double get targetVelocity => _targetVelocity;

  double get acceleration => _acceleration;

  DriveInstruction(this._distance, this._targetVelocity, this._acceleration);

  @override
  Map<String, dynamic> export() => {
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

  DriveForwardInstruction.fromJson(Map<String, dynamic> json)
      : this(json["distance"], json["target_velocity"], json["acceleration"]);

  @override
  Map<String, dynamic> toJson() => export();
}

class DriveForwardDistanceInstruction extends DriveInstruction {
  set distance(double value) => _distance = value;

  set initialVelocity(double value) => _targetVelocity = value;

  DriveForwardDistanceInstruction(double distance, double initialVelocity)
      : super(distance, initialVelocity, 0.0);

  DriveForwardDistanceInstruction.fromJson(Map<String, dynamic> json)
      : this(json["distance"], json["target_velocity"]);

  @override
  Map<String, double> toJson() =>
      {"distance": _distance, "target_velocity": _targetVelocity};
}

class DriveForwardTimeInstruction extends DriveInstruction
    implements Serializable {
  @protected
  double _time;
  double _initialVelocity;

  double get time => _time;

  set time(double value) {
    _time = value;
    _recalculate();
  }

  set initialVelocity(double value) {
    _initialVelocity = value;
    _recalculate();
  }

  void _recalculate() {
    _distance = _time * _targetVelocity;
  }

  DriveForwardTimeInstruction(this._time, this._initialVelocity)
      : super(_initialVelocity * _time, _initialVelocity, 0.0);

  DriveForwardTimeInstruction.fromJson(Map<String, dynamic> json)
      : this(json["time"], json["initial_velocity"]);

  @override
  Map<String, double> toJson() =>
      {"time": _time, "initial_velocity": _initialVelocity};
}

class AccelerateOverDistanceInstruction extends DriveInstruction
    implements Serializable {
  @protected
  double _initialVelocity;

  set acceleration(double newAcceleration) {
    _acceleration = newAcceleration;
    _recalculate();
  }

  set initialVelocity(double value) {
    _initialVelocity = value;
    _recalculate();
  }

  set distance(double newDistance) {
    _distance = newDistance;
    _recalculate();
  }

  void _recalculate() {
    _targetVelocity =
        _calculateFinalVelocity(_initialVelocity, distance, acceleration);
  }

  static double _calculateFinalVelocity(
      double initialVelocity, double distance, double acceleration) {
    double finalVelocitySquared =
        pow(initialVelocity, 2) + 2 * acceleration * distance;
    return sqrt(finalVelocitySquared < 0 ? 0 : finalVelocitySquared);
  }

  AccelerateOverDistanceInstruction({
    required double initialVelocity,
    required double distance,
    required double acceleration,
  })  : _initialVelocity = initialVelocity,
        super(
            distance,
            _calculateFinalVelocity(initialVelocity, distance, acceleration),
            acceleration);

  AccelerateOverDistanceInstruction.fromJson(Map<String, dynamic> json)
      : this(
          initialVelocity: json["initial_velocity"],
          distance: json["distance"],
          acceleration: json["acceleration"],
        );

  @override
  Map<String, dynamic> toJson() => {
        "initial_velocity": _initialVelocity,
        "distance": _distance,
        "acceleration": _acceleration,
      };
}

class AccelerateOverTimeInstruction extends DriveInstruction {
  @protected
  double _time, _initialVelocity;

  double get time => _time;

  set time(double newTime) {
    _time = newTime;
    _recalculate();
  }

  set initialVelocity(double value) {
    _initialVelocity = value;
    _recalculate();
  }

  set acceleration(double newAcceleration) {
    _acceleration = newAcceleration;
    _recalculate();
  }

  void _recalculate() {
    _targetVelocity =
        _calculateFinalVelocity(_initialVelocity, time, _acceleration);
    _distance = _calculateDistance(time, _initialVelocity, acceleration);
  }

  static double _calculateFinalVelocity(
      double initialVelocity, double time, double acceleration) {
    double finalVelocity = initialVelocity + acceleration * time;
    return finalVelocity > 0 ? finalVelocity : 0;
  }

  static double _calculateDistance(
      double time, double initialVelocity, double acceleration) {
    double distance =
        initialVelocity * time + 0.5 * acceleration * pow(time, 2);
    return distance > 0 ? distance : initialVelocity * time;
  }

  AccelerateOverTimeInstruction(
      this._initialVelocity, this._time, double acceleration)
      : super(
            _calculateDistance(_time, _initialVelocity, acceleration),
            _calculateFinalVelocity(_initialVelocity, _time, acceleration),
            acceleration);

  AccelerateOverTimeInstruction.fromJson(Map<String, dynamic> json)
      : this(json["initial_velocity"], json["time"], json["acceleration"]);

  @override
  Map<String, dynamic> toJson() => {
        "initial_velocity": _initialVelocity,
        "time": time,
        "acceleration": _acceleration
      };
}

class StopOverTimeInstruction extends AccelerateOverTimeInstruction {
  @override
  set time(double value) {
    _time = value;
    _recalculate();
  }

  @override
  set initialVelocity(double value) {
    _initialVelocity = value;
    _recalculate();
  }

  @override
  void _recalculate() {
    _acceleration = -_initialVelocity / _time;
  }

  StopOverTimeInstruction(double initialVelocity, double time)
      : super(initialVelocity, time, -initialVelocity / time);

  StopOverTimeInstruction.fromJson(Map<String, dynamic> json)
      : this(json["initial_velocity"], json["time"]);
}

class TurnInstruction extends MissionInstruction {
  double turnDegree, radius;
  bool left;

  TurnInstruction(this.turnDegree, this.left, this.radius);

  @override
  TurnInstruction.fromJson(Map<String, dynamic> json)
      : turnDegree = json["turn_degree"],
        left = json["left"],
        radius = json["radius"];

  @override
  Map<String, dynamic> toJson() =>
      {"turn_degree": turnDegree, "left": left, "radius": radius};

  @override
  Map<String, dynamic> export() => toJson();
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
