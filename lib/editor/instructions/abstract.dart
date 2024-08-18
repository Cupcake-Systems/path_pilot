import 'dart:math';

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
  final Function() removed;
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
    isLastInstruction = instructionIndex == simulationResult.instructionResults.length - 1;
  }

  String? _generateWarning() {
    if (_warning != null) return _warning;
    if (isLastInstruction && instructionResult.finalOuterVelocity.abs() > 0.00001) {
      return "Robi will not stop at the end";
    }
    if ((instructionResult.maxOuterVelocity - instruction.targetVelocity).abs() > 0.000001) {
      return "Robi will only reach ${roundToDigits(instructionResult.maxOuterVelocity * 100, 2)}cm/s";
    }
    return null;
  }
}

class RemovableWarningCard extends StatefulWidget {
  final Function() removed;
  final Function(InstructionResult instructionResult)? entered;
  final Function()? exited;
  final Function(MissionInstruction instruction) change;

  final Widget header;
  final List<TableRow> children;

  final InstructionResult instructionResult;
  final MissionInstruction instruction;

  final String? warningMessage;

  const RemovableWarningCard({
    super.key,
    required this.children,
    required this.instructionResult,
    required this.instruction,
    required this.removed,
    this.entered,
    this.exited,
    required this.change,
    this.warningMessage,
    required this.header,
  });

  @override
  State<RemovableWarningCard> createState() => _RemovableWarningCardState();

  static List<FlSpot> generateData(
    double acceleration,
    double initialVelocity,
    double finalVelocity,
    double maxVelocity,
    double accelerationDistance,
    double decelerationDistance,
    double totalDistance, {
    double scaleX = 1.0,
    double scaleY = 1.0,
  }) {
    final List<FlSpot> dataPoints = [];

    const resolution = 100;

    double dd = ((accelerationDistance + decelerationDistance) / totalDistance) * 0.01;
    if (dd <= 0) dd = 0.01;

    // Acceleration phase
    for (int i = 0; i < resolution; ++i) {
      final d = i / resolution * accelerationDistance;
      double velocity = sqrt(2 * acceleration * d + pow(initialVelocity, 2));
      dataPoints.add(FlSpot(d * scaleX, velocity * scaleY));
    }

    // Max velocity point
    dataPoints.add(FlSpot(accelerationDistance * scaleX, maxVelocity * scaleY));

    // Deceleration phase
    for (int i = 0; i < resolution; ++i) {
      final d = i / resolution * decelerationDistance + totalDistance - decelerationDistance;
      double velocity = sqrt(-2 * acceleration * (d - totalDistance) + pow(finalVelocity, 2));
      dataPoints.add(FlSpot(d * scaleX, velocity * scaleY));
    }

    // Final velocity point
    dataPoints.add(FlSpot(totalDistance * scaleX, finalVelocity * scaleY));
    return dataPoints;
  }

  static String vecToString(Vector2 vec, int decimalPlaces) => "(${vec.x.toStringAsFixed(decimalPlaces)}, ${vec.y.toStringAsFixed(decimalPlaces)})";
}

class _RemovableWarningCardState extends State<RemovableWarningCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    double maxX = 0, maxY = 0;
    List<FlSpot> data = [];
    String xAxisTitle = "", yAxisTitle = "";

    if (isExpanded) {
      if (widget.instructionResult is DriveResult) {
        final inst = widget.instructionResult as DriveResult;
        maxX = inst.totalDistance * 100;
        maxY = inst.maxVelocity * 100;
        data = _generateDataDrive(inst);
        xAxisTitle = "cm driven";
        yAxisTitle = "Velocity in cm/s";
      } else if (widget.instructionResult is TurnResult || widget.instructionResult is RapidTurnResult) {
        xAxisTitle = "Degrees turned";
        yAxisTitle = "Velocity in °/s";
        if (widget.instructionResult is TurnResult) {
          final inst = widget.instructionResult as TurnResult;
          maxX = inst.totalTurnDegree.abs();
          maxY = inst.maxAngularVelocity;
          data = _generateDataTurn(inst);
        } else if (widget.instructionResult is RapidTurnResult) {
          final inst = widget.instructionResult as RapidTurnResult;
          maxX = inst.totalTurnDegree.abs();
          maxY = inst.maxAngularVelocity;
          data = _generateDataRapidTurn(inst);
        } else {
          throw UnsupportedError("");
        }
      } else {
        throw UnsupportedError("");
      }
    }

    return MouseRegion(
      onEnter: (event) {
        if (widget.entered != null) widget.entered!(widget.instructionResult);
      },
      onExit: (event) {
        if (widget.exited != null) widget.exited!();
      },
      child: Card(
        child: Column(
          children: [
            ExpansionTile(
              onExpansionChanged: (value) => setState(() => isExpanded = value),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              childrenPadding: const EdgeInsets.all(8),
              title: widget.header,
              trailing: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: widget.removed,
                  icon: const Icon(Icons.delete),
                ),
              ),
              leading: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              subtitle: widget.warningMessage == null
                  ? null
                  : Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.yellow.withAlpha(50)),
                      child: Row(
                        children: [
                          const Icon(Icons.warning),
                          const SizedBox(width: 10),
                          Text(widget.warningMessage ?? ""),
                        ],
                      ),
                    ),
              children: isExpanded
                  ? [
                      Table(
                        columnWidths: const {
                          0: IntrinsicColumnWidth(),
                          1: FlexColumnWidth(),
                          2: IntrinsicColumnWidth(),
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          TableRow(
                            children: [
                              const Text("Acceleration"),
                              Slider(
                                value: widget.instruction.acceleration,
                                onChanged: (value) {
                                  widget.instruction.acceleration = roundToDigits(value, 3);
                                  widget.change(widget.instruction);
                                },
                              ),
                              Text("${roundToDigits(widget.instruction.acceleration * 100, 2)}cm/s²"),
                            ],
                          ),
                          TableRow(
                            children: [
                              const Text("Target Velocity"),
                              Slider(
                                value: widget.instruction.targetVelocity,
                                onChanged: (value) {
                                  widget.instruction.targetVelocity = roundToDigits(value, 3);
                                  widget.change(widget.instruction);
                                },
                                min: 0.001,
                              ),
                              Text("${roundToDigits(widget.instruction.targetVelocity * 100, 2)}cm/s"),
                            ],
                          ),
                          ...widget.children,
                        ],
                      ),
                      const SizedBox(height: 20),
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
                                  sideTitles: const SideTitles(showTitles: true, reservedSize: 40),
                                ),
                                bottomTitles: AxisTitles(
                                  axisNameWidget: Text(xAxisTitle),
                                  axisNameSize: 20,
                                  sideTitles: const SideTitles(showTitles: true, reservedSize: 30),
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
                      const SizedBox(height: 8),
                    ]
                  : const [],
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _generateDataDrive(DriveResult result) {
    return RemovableWarningCard.generateData(
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
    return RemovableWarningCard.generateData(
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
    return RemovableWarningCard.generateData(
      result.angularAcceleration,
      0,
      result.finalAngularVelocity,
      result.maxAngularVelocity,
      result.accelerationDegree,
      result.accelerationDegree,
      result.totalTurnDegree,
    );
  }
}
