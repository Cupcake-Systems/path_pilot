import 'dart:math';

import 'package:expandable/expandable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/editor.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../robi_api/robi_utils.dart';

abstract class AbstractEditor extends StatelessWidget {
  final SimulationResult simulationResult;
  final int instructionIndex;
  final MissionInstruction instruction;

  late final InstructionResult instructionResult;
  late final bool isLastInstruction;

  final Function(MissionInstruction newInstruction) change;
  final Function()? removed;
  final Function(InstructionResult instructionResult)? entered;
  final Function()? exited;

  late final String? warningMessage = _generateWarning();
  final String? _warning;

  AbstractEditor({
    super.key,
    required this.simulationResult,
    required this.instructionIndex,
    required this.change,
    required this.removed,
    required this.instruction,
    String? warning,
    this.entered,
    this.exited,
  }) : _warning = warning {
    instructionResult = simulationResult.instructionResults[instructionIndex];
    isLastInstruction =
        instructionIndex == simulationResult.instructionResults.length - 1;
  }

  String? _generateWarning() {
    if (_warning != null) return _warning;
    if (isLastInstruction &&
        instructionResult.finalOuterVelocity.abs() > 0.00001) {
      return "Robi will not stop at the end";
    }
    if ((instructionResult.maxOuterVelocity - instruction.targetVelocity)
            .abs() >
        0.000001) {
      return "Robi will only reach ${roundToDigits(instructionResult.maxOuterVelocity * 100, 2)}cm/s";
    }
    return null;
  }
}

class RemovableWarningCard extends StatelessWidget {
  final Function()? removed;
  final Function(InstructionResult instructionResult)? entered;
  final Function()? exited;
  final Function(MissionInstruction instruction) change;

  final Widget header;
  final List<Widget> children;

  final InstructionResult instructionResult;
  final MissionInstruction instruction;

  final String? warningMessage;

  const RemovableWarningCard({
    super.key,
    required this.children,
    required this.instructionResult,
    required this.instruction,
    this.removed,
    this.entered,
    this.exited,
    required this.change,
    this.warningMessage,
    required this.header,
  });

  @override
  Widget build(BuildContext context) {
    double maxX, maxY;
    List<FlSpot> data;
    String xAxisTitle, yAxisTitle;

    if (instructionResult is DriveResult) {
      final inst = instructionResult as DriveResult;
      maxX = inst.totalDistance * 100;
      maxY = inst.maxVelocity * 100;
      data = _generateDataDrive(inst);
      xAxisTitle = "cm driven";
      yAxisTitle = "Velocity in cm/s";
    } else if (instructionResult is TurnResult ||
        instructionResult is RapidTurnResult) {
      xAxisTitle = "Degrees turned";
      yAxisTitle = "Velocity in °/s";
      if (instructionResult is TurnResult) {
        final inst = instructionResult as TurnResult;
        maxX = inst.totalTurnDegree.abs();
        maxY = inst.maxAngularVelocity;
        data = _generateDataTurn(inst);
      } else if (instructionResult is RapidTurnResult) {
        final inst = instructionResult as RapidTurnResult;
        maxX = inst.totalTurnDegree.abs();
        maxY = inst.maxAngularVelocity;
        data = _generateDataRapidTurn(inst);
      } else {
        throw UnsupportedError("");
      }
    } else {
      throw UnsupportedError("");
    }

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
                  header,
                  const Spacer(),
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
                    SizedBox(
                      height: 200,
                      child: ListView(
                        children: [
                          Row(
                            children: [
                              const Text("Acceleration"),
                              Slider(
                                value: instruction.acceleration,
                                onChanged: (value) {
                                  instruction.acceleration = value;
                                  change(instruction);
                                },
                              ),
                              Text(
                                  "${roundToDigits(instruction.acceleration * 100, 2)}cm/s²"),
                            ],
                          ),
                          Row(
                            children: [
                              const Text("Target Velocity"),
                              Slider(
                                value: instruction.targetVelocity,
                                onChanged: (value) {
                                  instruction.targetVelocity = value;
                                  change(instruction);
                                },
                                min: 0.001,
                              ),
                              Text(
                                  "${roundToDigits(instruction.targetVelocity * 100, 2)}cm/s"),
                            ],
                          ),
                          ...children
                        ],
                      ),
                    ),
                    const Divider(),
                    SizedBox(
                      height: 300,
                      child: AspectRatio(
                        aspectRatio: 2,
                        child: LineChart(
                          LineChartData(
                            minX: 0,
                            minY: 0,
                            maxX: maxX,
                            maxY: maxY,
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(),
                              rightTitles: const AxisTitles(),
                              leftTitles: AxisTitles(
                                axisNameWidget: Text(yAxisTitle),
                                sideTitles: const SideTitles(
                                    showTitles: true, reservedSize: 40),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameWidget: Text(xAxisTitle),
                                sideTitles: const SideTitles(
                                    showTitles: true, reservedSize: 40),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: data,
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
      double acceleration,
      double initialVelocity,
      double finalVelocity,
      double maxVelocity,
      double accelerationDistance,
      double decelerationDistance,
      double totalDistance,
      {double scaleX = 1.0,
      double scaleY = 1.0}) {
    List<FlSpot> dataPoints = [];
    const dd = 0.001;

    // Acceleration phase
    for (double d = 0; d <= accelerationDistance; d += dd) {
      double velocity = sqrt(2 * acceleration * d + pow(initialVelocity, 2));
      dataPoints.add(FlSpot(d * scaleX, velocity * scaleY));
    }

    // Max velocity point
    dataPoints.add(FlSpot(accelerationDistance * scaleX, maxVelocity * scaleY));

    // Deceleration phase
    for (double d = totalDistance - decelerationDistance;
        d < totalDistance;
        d += dd) {
      double velocity =
          sqrt(-2 * acceleration * (d - totalDistance) + pow(finalVelocity, 2));
      dataPoints.add(FlSpot(d * scaleX, velocity * scaleY));
    }

    // Final velocity point
    dataPoints.add(FlSpot(totalDistance * scaleX, finalVelocity * scaleY));

    return dataPoints;
  }

  List<FlSpot> _generateDataDrive(DriveResult result) {
    return _generateData(
      result.acceleration,
      result.initialVelocity,
      result.finalVelocity,
      result.maxVelocity,
      result.accelerationDistance,
      result.decelerationDistance,
      result.totalDistance,
      scaleX: 100,
      scaleY: 100,
    );
  }

// Refactored _generateDataTurn function
  List<FlSpot> _generateDataTurn(TurnResult result) {
    return _generateData(
      result.angularAcceleration,
      result.initialAngularVelocity,
      result.finalAngularVelocity,
      result.maxAngularVelocity,
      result.accelerationDegree,
      result.decelerationDegree,
      result.totalTurnDegree,
    );
  }

// Refactored _generateDataRapidTurn function
  List<FlSpot> _generateDataRapidTurn(RapidTurnResult result) {
    return _generateData(
      result.angularAcceleration,
      0,
      result.finalAngularVelocity,
      result.maxAngularVelocity,
      result.accelerationDegree,
      result.accelerationDegree,
      result.totalTurnDegree,
    );
  }

  static String vecToString(Vector2 vec, int decimalPlaces) =>
      "(${vec.x.toStringAsFixed(decimalPlaces)}, ${vec.y.toStringAsFixed(decimalPlaces)})";
}
