import 'package:robi_line_drawer/editor/editor.dart';

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
        'a': roundToDigits(acceleration.abs(), 3),
        'vi': roundToDigits(initialVelocity.abs(), 4),
        'ta': roundToDigits(accelerationTime.abs(), 4),
        'td': roundToDigits(decelerationTime.abs(), 4),
        'tc': roundToDigits(constantSpeedTime.abs(), 4),
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
        'a': roundToDigits(acceleration.abs(), 3),
        'vi': roundToDigits(initialVelocity.abs(), 4),
        'l': left ? 1 : 0,
        'dt': totalTurnDegree.abs().toInt(),
        'ri': roundToDigits(innerRadius.abs(), 3),
        'da': roundToDigits(accelerationDegree.abs(), 2),
        'dd': roundToDigits(decelerationDegree.abs(), 2),
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
        'a': roundToDigits(acceleration.abs(), 3),
        'l': left ? 1 : 0,
        'dt': totalTurnDegree.abs().toInt(),
        'da': roundToDigits(accelerationDegree.abs(), 2),
      };
}
