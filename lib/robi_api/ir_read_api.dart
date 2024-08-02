import 'dart:io';

class Measurement {
  final int motorLeftFreq, motorRightFreq, leftIr, middleIr, rightIr;
  final bool leftFwd, rightFwd;

  const Measurement({
    required this.motorLeftFreq,
    required this.motorRightFreq,
    required this.leftIr,
    required this.middleIr,
    required this.rightIr,
    required this.leftFwd,
    required this.rightFwd,
  });

  factory Measurement.fromLine(String line) {
    line = line.trim();
    final s = line.split(" : ");
    final motorSplit = s[0].split(" ");
    final fwdSplit = s[1].split(" ");
    final irSplit = s[2].split(", ");
    return Measurement(
      motorLeftFreq: int.parse(motorSplit[0]),
      motorRightFreq: int.parse(motorSplit[1]),
      leftIr: int.parse(irSplit[0]),
      middleIr: int.parse(irSplit[1]),
      rightIr: int.parse(irSplit[2]),
      leftFwd: bool.parse(fwdSplit[0], caseSensitive: false),
      rightFwd: bool.parse(fwdSplit[1], caseSensitive: false),
    );
  }
}

class IrReadResult {
  final double resolution;
  final List<Measurement> measurements;

  IrReadResult({required this.resolution, required this.measurements});

  factory IrReadResult.fromData(String data) {
    final lines = data.trim().split("\n");
    return IrReadResult(
      resolution: double.parse(lines[0].trim()),
      measurements:
      lines.sublist(1).map((e) => Measurement.fromLine(e)).toList(),
    );
  }

  factory IrReadResult.fromFile(File file) =>
      IrReadResult.fromData(file.readAsStringSync());
}
