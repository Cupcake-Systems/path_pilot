abstract class ExportedMissionInstruction {
  ExportedMissionInstruction({
    required this.acceleration,
    required this.initialVelocity,
  }) {
    assert(acceleration >= 0);
    assert(initialVelocity >= 0);
  }

  Map<String, dynamic> toJson();

  final double acceleration;
  final double initialVelocity;
}

class ExportedDriveInstruction extends ExportedMissionInstruction {
  ExportedDriveInstruction({
    required super.acceleration,
    required super.initialVelocity,
    required this.accelerationTime,
    required this.decelerationTime,
    required this.constantSpeedTime,
  }) {
    assert(accelerationTime >= 0);
    assert(decelerationTime >= 0);
    assert(constantSpeedTime >= 0);
  }

  final double accelerationTime;
  final double decelerationTime;
  final double constantSpeedTime;

  // .abs() to convert -0.0 to 0
  @override
  Map<String, dynamic> toJson() => {
        'acceleration': acceleration.abs(),
        'initial_velocity': initialVelocity.abs(),
        'acceleration_time': accelerationTime.abs(),
        'deceleration_time': decelerationTime.abs(),
        'constant_speed_time': constantSpeedTime.abs(),
      };
}

class ExportedTurnInstruction extends ExportedMissionInstruction {
  ExportedTurnInstruction({
    required super.acceleration,
    required super.initialVelocity,
    required this.left,
    required this.totalTurnDegree,
    required this.innerRadius,
    required this.accelerationDegree,
    required this.decelerationDegree,
  }) {
    assert(totalTurnDegree >= 0);
    assert(innerRadius >= 0);
    assert(accelerationDegree >= 0);
    assert(decelerationDegree >= 0);
  }

  final bool left;
  final double totalTurnDegree;
  final double innerRadius;
  final double accelerationDegree;
  final double decelerationDegree;

  // .abs() to convert -0.0 to 0
  @override
  Map<String, dynamic> toJson() => {
        'acceleration': acceleration.abs(),
        'initial_velocity': initialVelocity.abs(),
        'left': left,
        'total_turn_degree': totalTurnDegree.abs(),
        'inner_radius': innerRadius.abs(),
        'acceleration_degree': accelerationDegree.abs(),
        'deceleration_degree': decelerationDegree.abs(),
      };
}

class ExportedRapidTurnInstruction extends ExportedTurnInstruction {
  ExportedRapidTurnInstruction({
    required super.acceleration,
    required super.left,
    required super.totalTurnDegree,
    required super.accelerationDegree,
  }) : super(
          initialVelocity: 0,
          innerRadius: 0,
          decelerationDegree: accelerationDegree,
        ) {
    assert(totalTurnDegree >= 0);
    assert(accelerationDegree >= 0);
  }

  // .abs() to convert -0.0 to 0
  @override
  Map<String, dynamic> toJson() => {
        'acceleration': acceleration.abs(),
        'initial_velocity': initialVelocity.abs(),
        'left': left,
        'total_turn_degree': totalTurnDegree.abs(),
        'acceleration_degree': accelerationDegree.abs(),
      };
}
