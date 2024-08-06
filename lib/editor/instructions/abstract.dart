import 'dart:math';
import 'dart:ui';

import 'package:expandable/expandable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/editor.dart';
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
  final Function(InstructionResult instructionResult)? entered;
  final Function()? exited;

  String? warningMessage;

  AbstractEditor({
    super.key,
    required this.instruction,
    required this.simulationResult,
    required this.instructionIndex,
    required this.change,
    required this.removed,
    this.warningMessage,
    this.entered,
    this.exited,
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

    if (isLastInstruction && instructionResult.finalVelocity > 0.00001) {
      warningMessage = "Robi will not stop at the end";
    }
  }
}

class RemovableWarningCard extends StatelessWidget {
  final Function()? removed;
  final Function(InstructionResult instructionResult)? entered;
  final Function()? exited;

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
    this.entered,
    this.exited,
    this.warningMessage,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        if (entered != null) entered!(instructionResult);
      },
      onExit: (event) {
        if (exited != null) exited!();
      },
      child: Card(
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
                                "Initial Velocity: ${roundToDigits(prevResult.maxVelocity * 100, 2)}cm/s"),
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
                                "End Velocity: ${roundToDigits(instructionResult.finalVelocity * 100, 2)}cm/s (Max.: ${roundToDigits(instructionResult.maxVelocity * 100, 2)}cm/s)"),
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
                    SizedBox(
                      height: 300,
                      child: AspectRatio(
                        aspectRatio: 2,
                        child: LineChart(
                          LineChartData(
                            minX: 0,
                            minY: 0,
                            maxX: instructionResult.startPosition
                                .distanceTo(instructionResult.endPosition),
                            maxY: instructionResult.maxVelocity,
                            titlesData: const FlTitlesData(
                              topTitles: AxisTitles(),
                              rightTitles: AxisTitles(),
                              leftTitles: AxisTitles(
                                axisNameWidget: Text("Velocity in m/s"),
                                sideTitles: SideTitles(
                                    showTitles: true, reservedSize: 40),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: Text("Distance in m"),
                                sideTitles: SideTitles(
                                    showTitles: true, reservedSize: 40),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _generateData(
                                    instruction, instructionResult),
                                color: Colors.grey,
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
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
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(10)),
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
      ),
    );
  }

  List<FlSpot> _generateData(
      MissionInstruction instruction, InstructionResult result,
      {double resolution = 0.01}) {
    if (instruction is! DriveInstruction || result is! DriveResult) return [];

    final totalDistance = result.startPosition.distanceTo(result.endPosition);

    List<FlSpot> dataPoints = [];

    for (double d = 0;
        d <= result.startPosition.distanceTo(result.accelerationEndPoint);
        d += resolution) {
      double velocity = sqrt(2 * instruction.acceleration * d +
          pow(result.initialVelocity, 2));
      dataPoints.add(FlSpot(d, velocity));
    }

    dataPoints.add(FlSpot(
        result.startPosition.distanceTo(result.accelerationEndPoint),
        result.maxVelocity));

    for (double d =
            result.startPosition.distanceTo(result.decelerationStartPoint);
        d < totalDistance;
        d += resolution) {
      double velocity = sqrt(
          -2 * instruction.acceleration * (d - totalDistance) +
              pow(result.finalVelocity, 2));
      dataPoints.add(FlSpot(d, velocity));
    }

    dataPoints.add(FlSpot(totalDistance, result.finalVelocity));

    return dataPoints;
  }

  static String vecToString(Vector2 vec, int decimalPlaces) =>
      "(${vec.x.toStringAsFixed(decimalPlaces)}, ${vec.y.toStringAsFixed(decimalPlaces)})";
}
