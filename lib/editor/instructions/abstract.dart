import 'dart:math';
import 'dart:ui';

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/editor.dart';
import 'package:robi_line_drawer/editor/line_painter.dart';
import 'package:robi_line_drawer/robi_api/robi_path_serializer.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../robi_api/robi_utils.dart';

abstract class AbstractEditor extends StatelessWidget {
  final MissionInstruction instruction;
  final SimulationResult simulationResult;
  final int instructionIndex;

  late final InstructionResult prevInstructionResult;
  late final InstructionResult instructionResult;
  late final bool isLastInstruction;

  final Function(MissionInstruction newInstruction) change;
  final Function()? removed;

  String? warningMessage;

  AbstractEditor({
    super.key,
    required this.instruction,
    required this.simulationResult,
    required this.instructionIndex,
    required this.change,
    this.removed,
    this.warningMessage,
  }) {
    if (instructionIndex > 0) {
      prevInstructionResult = simulationResult.instructionResults
              .elementAtOrNull(instructionIndex - 1) ??
          startResult;
    } else {
      prevInstructionResult = startResult;
    }

    instructionResult = simulationResult.instructionResults[instructionIndex];
    isLastInstruction =
        instructionIndex == simulationResult.instructionResults.length - 1;

    if (isLastInstruction && instructionResult.managedVelocity > 0) {
      warningMessage = "Robi will not stop at the end";
    }
  }
}

class RemovableWarningCard extends StatelessWidget {
  final Function()? removed;

  final List<Widget> children;

  final InstructionResult prevResult;
  final InstructionResult instructionResult;
  final MissionInstruction instruction;

  final String? warningMessage;

  const RemovableWarningCard({
    super.key,
    required this.children,
    required this.prevResult,
    required this.instructionResult,
    required this.instruction,
    this.removed,
    this.warningMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ExpandablePanel(
            header: Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: children,
                  ),
                ),
                if (removed != null)
                  IconButton(
                      onPressed: removed, icon: const Icon(Icons.delete)),
                const SizedBox(width: 40),
              ],
            ),
            collapsed: const SizedBox.shrink(),
            expanded: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  const Divider(),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              "Initial Velocity: ${roundToDigits(prevResult.managedVelocity * 100, 2)}cm/s"),
                          Text(
                              "Initial Position: ${vecToString(prevResult.endPosition, 2)}m"),
                          Text(
                              "Initial Rotation: ${roundToDigits(prevResult.endRotation, 2)}°"),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.arrow_forward),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              "End Velocity: ${roundToDigits(instructionResult.managedVelocity * 100, 2)}cm/s"),
                          Text(
                              "End Position: ${vecToString(instructionResult.endPosition, 2)}m"),
                          Text(
                              "End Rotation: ${roundToDigits(instructionResult.endRotation, 2)}°"),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      //borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    width: 200,
                    height: 200,
                    child: CustomPaint(
                      painter: DriveInstructionGraphDrawer(
                        prevInstResult: prevResult,
                        instructionResult: instructionResult,
                        instruction: instruction,
                      ),
                      child: Container(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            theme: const ExpandableThemeData(
                iconPlacement: ExpandablePanelIconPlacement.left,
                inkWellBorderRadius: BorderRadius.all(Radius.circular(10)),
                iconColor: Colors.white),
          ),
          if (warningMessage != null) ...[
            const Divider(height: 0),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(10)),
                  color: Colors.yellow.withAlpha(50)),
              child: Row(
                children: [
                  const Icon(Icons.warning),
                  const SizedBox(width: 10),
                  Text(warningMessage!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String vecToString(Vector2 vec, int decimalPlaces) =>
      "(${vec.x.toStringAsFixed(decimalPlaces)}, ${vec.y.toStringAsFixed(decimalPlaces)})";
}

class DriveInstructionGraphDrawer extends CustomPainter {
  final InstructionResult prevInstResult;
  final InstructionResult instructionResult;
  final MissionInstruction instruction;

  static final graphPaint = Paint()
    ..color = Colors.grey
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;

  const DriveInstructionGraphDrawer({
    required this.prevInstResult,
    required this.instructionResult,
    required this.instruction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      drawInstruction(canvas, size);
    } on Exception {}
  }

  void drawInstruction(Canvas canvas, Size size) {
    final isDriveInst = instruction is DriveInstruction;

    final highestVelocity = [
      prevInstResult.managedVelocity,
      if (isDriveInst) (instruction as DriveInstruction).targetVelocity,
      instructionResult.managedVelocity
    ].reduce(max);

    final totalDistanceCovered =
        prevInstResult.endPosition.distanceTo(instructionResult.endPosition);

    final velocityStart =
        Vector2(0, prevInstResult.managedVelocity / highestVelocity);
    final velocityEnd = Vector2(
        isDriveInst
            ? ((instructionResult as DriveResult).accelerationDistance /
                totalDistanceCovered)
            : 1,
        instructionResult.managedVelocity / highestVelocity);

    canvas.drawLine(vecToOffset(velocityStart, size),
        vecToOffset(velocityEnd * 1.002, size), graphPaint);
    canvas.drawLine(vecToOffset(velocityEnd, size),
        vecToOffset(Vector2(1, velocityEnd.y), size), graphPaint);

    LinePainter.paintText("0",
        vecToOffset(Vector2.zero(), size).translate(-10, 10), canvas, size);

    if (prevInstResult.managedVelocity > 0) {
      if (highestVelocity != prevInstResult.managedVelocity) {
        drawDashedLine(
          canvas: canvas,
          p1: vecToOffset(velocityStart, size),
          p2: vecToOffset(Vector2(1, velocityStart.y), size),
          pattern: const [10, 10],
          paint: Paint()
            ..strokeWidth = 2
            ..color = Colors.grey.withAlpha(100)
            ..style = PaintingStyle.stroke,
        );
      }
      LinePainter.paintText(
          "${(prevInstResult.managedVelocity * 100).toStringAsFixed(2)}cm/s",
          vecToOffset(velocityStart, size).translate(-40, 7),
          canvas,
          size);
    }

    if (highestVelocity != instructionResult.managedVelocity &&
        instructionResult.managedVelocity != 0) {
      drawDashedLine(
        canvas: canvas,
        p1: vecToOffset(Vector2(0, velocityEnd.y), size),
        p2: vecToOffset(Vector2(1, velocityEnd.y), size),
        pattern: const [10, 10],
        paint: Paint()
          ..strokeWidth = 2
          ..color = Colors.grey.withAlpha(100)
          ..style = PaintingStyle.stroke,
      );
    }
    LinePainter.paintText(
        "${(instructionResult.managedVelocity * 100).toStringAsFixed(2)}cm/s",
        vecToOffset(Vector2(1, velocityEnd.y), size).translate(45, 7),
        canvas,
        size);

    if (velocityEnd.x > 0) {
      if (velocityEnd.x < 0.99999) {
        drawDashedLine(
          canvas: canvas,
          p1: vecToOffset(Vector2(velocityEnd.x, 0), size),
          p2: vecToOffset(Vector2(velocityEnd.x, 1), size),
          pattern: const [10, 10],
          paint: Paint()
            ..strokeWidth = 2
            ..color = Colors.grey.withAlpha(100)
            ..style = PaintingStyle.stroke,
        );
      }
      if (isDriveInst) {
        LinePainter.paintText(
            "${(instructionResult as DriveResult).accelerationDistance.toStringAsFixed(2)}m",
            vecToOffset(Vector2(velocityEnd.x, 0), size).translate(0, 20),
            canvas,
            size);
      }
    }
  }

  void drawDashedLine({
    required Canvas canvas,
    required Offset p1,
    required Offset p2,
    required Iterable<double> pattern,
    required Paint paint,
  }) {
    assert(pattern.length.isEven);
    final distance = (p2 - p1).distance;
    final normalizedPattern = pattern.map((width) => width / distance).toList();
    final points = <Offset>[];
    double t = 0;
    int i = 0;
    while (t < 1) {
      points.add(Offset.lerp(p1, p2, t)!);
      t += normalizedPattern[i++]; // dashWidth
      points.add(Offset.lerp(p1, p2, t.clamp(0, 1))!);
      t += normalizedPattern[i++]; // dashSpace
      i %= normalizedPattern.length;
    }
    canvas.drawPoints(PointMode.lines, points, paint);
  }

  Offset vecToOffset(Vector2 vec, Size size) {
    return Offset(vec.x * size.height, size.height - vec.y * size.height);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
