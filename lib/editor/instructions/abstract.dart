import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/editor.dart';
import 'package:robi_line_drawer/editor/painters/robi_painter.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../robi_api/robi_utils.dart';

abstract class AbstractEditor extends StatelessWidget {
  final SimulationResult simulationResult;
  final int instructionIndex;
  final MissionInstruction instruction;
  final RobiConfig robiConfig;

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
    required this.robiConfig,
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
  final RobiConfig robiConfig;

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
    required this.robiConfig,
  });

  @override
  State<RemovableWarningCard> createState() => _RemovableWarningCardState();
}

String vecToString(Vector2 vec, int decimalPlaces) => "(${vec.x.toStringAsFixed(decimalPlaces)}, ${vec.y.toStringAsFixed(decimalPlaces)})";

class _RemovableWarningCardState extends State<RemovableWarningCard> {
  static const iterations = 500;

  bool isExpanded = false;
  late XAxisType xAxisMode = widget.instruction is RapidTurnResult ? XAxisType.time : XAxisType.position;
  YAxisType yAxisMode = YAxisType.velocity;
  late bool angular = widget.instruction is! DriveInstruction;

  @override
  Widget build(BuildContext context) {
    final List<InnerOuterRobiState> chartStates = List.generate(
      iterations,
      (i) => getRobiStateAtTimeInInstructionResult(widget.instructionResult, i / (iterations - 1) * widget.instructionResult.outerTotalTime),
    );
    List<FlSpot> data1 = [];
    List<FlSpot>? data2;
    String xAxisTitle;
    String yAxisTitle;

    bool angularX = angular;
    bool angularY = angular;

    if (widget.instructionResult is RapidTurnResult) {
      angularX = true;
    }

    if (xAxisMode == XAxisType.time) {
      xAxisTitle = "Time in s";
    } else {
      if (angularX) {
        xAxisTitle = "Rotation in °";
      } else {
        xAxisTitle = "Distance driven in cm";
      }
    }

    if (yAxisMode == YAxisType.velocity) {
      yAxisTitle = "Velocity in ${angularY ? "°/s" : "cm/s"}";
    } else {
      yAxisTitle = "Acceleration in ${angularY ? "°/s²" : "cm/s²"}";
    }

    double minY = 0;

    if (isExpanded) {
      if (angular) {
        data1 = mergeData(
          xValues(
            widget.instructionResult,
            chartStates,
            xAxisMode,
            angularX,
          ),
          yAngularValues(
            widget.instructionResult,
            chartStates,
            yAxisMode,
            angularY,
          ),
        );
      } else {
        data1 = mergeData(
          xValues(
            widget.instructionResult,
            chartStates,
            xAxisMode,
            angularX,
          ),
          yInnerValues(
            widget.instructionResult,
            chartStates,
            yAxisMode,
          ),
        );
        if (widget.instructionResult is TurnResult) {
          data2 = mergeData(
            xValues(
              widget.instructionResult,
              chartStates,
              xAxisMode,
              angularX,
            ),
            yOuterValues(
              widget.instructionResult,
              chartStates,
              yAxisMode,
            ),
          );
        }
      }

      minY = 0;
      if (data1.isNotEmpty) {
        minY = data1.map((spot) => spot.y).reduce(min);
      }
      if (data2 != null && data2.isNotEmpty) {
        minY = min(minY, data2.map((spot) => spot.y).reduce(min));
      }
      if (minY > 0) {
        minY = 0;
      }
    }

    return MouseRegion(
      onEnter: (event) {
        widget.entered?.call(widget.instructionResult);
      },
      onExit: (event) {
        widget.exited?.call();
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
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          SizedBox(
                            height: 300,
                            child: AspectRatio(
                              aspectRatio: 2,
                              child: LineChart(
                                LineChartData(
                                  borderData: FlBorderData(
                                    border: Border.all(color: const Color(0xff37434d), width: 2),
                                  ),
                                  minY: minY,
                                  lineTouchData: LineTouchData(
                                    touchTooltipData: LineTouchTooltipData(
                                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                        return touchedSpots.map((LineBarSpot touchedSpot) {
                                          final spot = touchedSpot as FlSpot;
                                          final end = touchedSpots.last == touchedSpot ? "" : "\n";
                                          String leading = "";

                                          if (touchedSpots.length == 2) {
                                            leading = touchedSpot == touchedSpots.first ? "Inner " : "Outer ";
                                          }

                                          return LineTooltipItem(
                                            "$leading$yAxisTitle: ${spot.y.toStringAsFixed(2)}$end",
                                            const TextStyle(),
                                          );
                                        }).toList();
                                      },
                                    ),
                                  ),
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
                                      spots: data1,
                                      color: data2 == null ? Colors.grey : Colors.red,
                                      dotData: const FlDotData(show: false),
                                    ),
                                    if (data2 != null)
                                      LineChartBarData(
                                        spots: data2,
                                        color: Colors.blue,
                                        dotData: const FlDotData(show: false),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.instructionResult is! DriveResult)
                                    CheckboxListTile(
                                      value: angular,
                                      onChanged: (value) => setState(() => angular = value!),
                                      title: const Text("Angular"),
                                    ),
                                  const Text("X-Axis"),
                                  ListTile(
                                    leading: Radio(value: XAxisType.time, groupValue: xAxisMode, onChanged: (value) => setState(() => xAxisMode = value!)),
                                    title: const Text("Time"),
                                  ),
                                  ListTile(
                                    leading: Radio(value: XAxisType.position, groupValue: xAxisMode, onChanged: (value) => setState(() => xAxisMode = value!)),
                                    title: const Text("Position"),
                                  ),
                                  const Text("Y-Axis"),
                                  ListTile(
                                    leading: Radio(value: YAxisType.velocity, groupValue: yAxisMode, onChanged: (value) => setState(() => yAxisMode = value!)),
                                    title: const Text("Velocity"),
                                  ),
                                  ListTile(
                                    leading: Radio(value: YAxisType.acceleration, groupValue: yAxisMode, onChanged: (value) => setState(() => yAxisMode = value!)),
                                    title: const Text("Acceleration"),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
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

  List<double> xValues(final InstructionResult res, final List<InnerOuterRobiState> states, final XAxisType xAxis, final bool angular) {
    return states.map((state) {
      if (xAxis == XAxisType.time) {
        return state.timeStamp - res.timeStamp;
      } else {
        return angular ? state.rotation - res.startRotation : res.startPosition.distanceTo(state.position) * 100;
      }
    }).toList();
  }

  List<double> yAngularValues(final InstructionResult res, final List<InnerOuterRobiState> states, final YAxisType yAxis, final bool angular) {
    return states.map((state) {
      double y = 0;

      if (yAxis == YAxisType.velocity) {
        if (res is TurnResult) {
          y = (state.outerVelocity - state.innerVelocity) / widget.robiConfig.trackWidth * (180 / pi);
        } else if (res is RapidTurnResult) {
          y = state.outerVelocity / (widget.robiConfig.trackWidth * pi) * 360;
        }
      } else {
        if (res is TurnResult) {
          y = (state.outerAcceleration - state.innerAcceleration) / widget.robiConfig.trackWidth * (180 / pi);
        } else if (res is RapidTurnResult) {
          y = state.outerAcceleration / (widget.robiConfig.trackWidth * pi) * 360;
        }
      }

      return y;
    }).toList();
  }

  List<double> yOuterValues(final InstructionResult res, final List<InnerOuterRobiState> states, final YAxisType yAxis) {
    return states.map((state) {
      double y = 0;

      if (yAxis == YAxisType.velocity) {
        y = state.outerVelocity;
      } else {
        y = state.outerAcceleration;
      }

      return y * 100;
    }).toList();
  }

  List<double> yInnerValues(final InstructionResult res, final List<InnerOuterRobiState> states, final YAxisType yAxis) {
    return states.map((state) {
      double y = 0;

      if (yAxis == YAxisType.velocity) {
        y = state.innerVelocity;
      } else {
        y = state.innerAcceleration;
      }

      return y * 100;
    }).toList();
  }

  List<FlSpot> mergeData(final List<double> xValues, final List<double> yValues) => List.generate(
        xValues.length,
        (i) => FlSpot(xValues[i], yValues[i]),
        growable: false,
      );
}

enum XAxisType {
  time,
  position,
}

enum YAxisType {
  velocity,
  acceleration,
}
