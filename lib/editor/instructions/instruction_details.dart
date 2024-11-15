import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';

import '../painters/robi_painter.dart';

class InstructionDetailsWidget extends StatefulWidget {
  final InstructionResult instructionResult;
  final RobiConfig robiConfig;
  final double? instructionProgress;

  const InstructionDetailsWidget({
    super.key,
    required this.instructionResult,
    required this.robiConfig,
    this.instructionProgress,
  });

  @override
  State<InstructionDetailsWidget> createState() => _InstructionDetailsWidgetState();
}

class _InstructionDetailsWidgetState extends State<InstructionDetailsWidget> {
  static const iterations = 100;

  late XAxisType xAxisMode = widget.instructionResult is RapidTurnResult ? XAxisType.time : XAxisType.position;
  YAxisType yAxisMode = YAxisType.velocity;
  late bool angular = widget.instructionResult is! DriveResult;

  @override
  Widget build(BuildContext context) {
    final List<InnerOuterRobiState> chartStates = List.generate(
      iterations,
      (i) => getRobiStateAtTimeInInstructionResult(
        widget.instructionResult,
        i / (iterations - 1) * widget.instructionResult.totalTime,
      ),
      growable: false,
    );
    List<FlSpot> data1 = [];
    List<FlSpot>? data2;

    late final String xAxisTitle;
    late final String yAxisTitle;

    bool angularX = angular;
    bool angularY = angular;

    if (widget.instructionResult is RapidTurnResult) {
      angularX = true;
    }

    switch (xAxisMode) {
      case XAxisType.time:
        xAxisTitle = "Time in s";
        break;
      case XAxisType.position:
        if (angularX) {
          xAxisTitle = "Rotation in °";
        } else {
          xAxisTitle = "Distance driven in cm";
        }
        break;
    }

    switch (yAxisMode) {
      case YAxisType.position:
        if (angularX) {
          yAxisTitle = "Rotation in °";
        } else {
          yAxisTitle = "Distance driven in cm";
        }
        break;
      case YAxisType.velocity:
        yAxisTitle = "Velocity in ${angularY ? "°/s" : "cm/s"}";
        break;
      case YAxisType.acceleration:
        yAxisTitle = "Acceleration in ${angularY ? "°/s²" : "cm/s²"}";
        break;
    }

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

    double minY = 0;
    double maxX = 0;

    switch (xAxisMode) {
      case XAxisType.time:
        maxX = widget.instructionResult.totalTime;
        break;
      case XAxisType.position:
        if (angularX) {
          if (widget.instructionResult is RapidTurnResult) {
            maxX = (widget.instructionResult as RapidTurnResult).totalTurnDegree;
          } else {
            maxX = (widget.instructionResult as TurnResult).totalTurnDegree;
          }
        } else {
          maxX = chartStates.last.position.distanceTo(widget.instructionResult.startPosition) * 100;
        }
        break;
    }

    if (data1.isNotEmpty) {
      minY = data1.map((spot) => spot.y).reduce(min);
    }
    if (data2 != null && data2.isNotEmpty) {
      minY = min(minY, data2.map((spot) => spot.y).reduce(min));
    }
    if (minY > 0) {
      minY = 0;
    }

    final color1 = data2 == null ? Colors.grey : Colors.red;
    final color2 = Colors.blue;

    return SizedBox(
      height: 400,
      child: Row(
        children: [
          Flexible(
            flex: 2,
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
                    isStepLineChart: yAxisMode == YAxisType.acceleration,
                    spots: data1,
                    color: color1,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [color1.withOpacity(0.3), color1.withOpacity(0.3), Colors.transparent, Colors.transparent],
                        stops: [0, widget.instructionProgress ?? 1, widget.instructionProgress ?? 1, 1],
                      ),
                    ),
                  ),
                  if (data2 != null)
                    LineChartBarData(
                      isStepLineChart: yAxisMode == YAxisType.acceleration,
                      spots: data2,
                      color: color2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [color2.withOpacity(0.3), color2.withOpacity(0.3), Colors.transparent, Colors.transparent],
                          stops: [0, widget.instructionProgress ?? 1, widget.instructionProgress ?? 1, 1],
                        ),
                      ),
                    ),
                ],
                extraLinesData: widget.instructionProgress == null
                    ? null
                    : ExtraLinesData(
                        verticalLines: [
                          VerticalLine(
                            x: widget.instructionProgress! * maxX,
                            color: Colors.grey,
                            dashArray: [5, 5],
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
                    leading: Radio(value: YAxisType.position, groupValue: yAxisMode, onChanged: (value) => setState(() => yAxisMode = value!)),
                    title: const Text("Position"),
                  ),
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
    );
  }

  List<double> xValues(final InstructionResult res, final List<InnerOuterRobiState> states, final XAxisType xAxis, final bool angular) {
    return states.map((state) {
      if (xAxis == XAxisType.time) {
        return state.timeStamp - res.timeStamp;
      } else {
        return angular ? (state.rotation - res.startRotation).abs() : res.startPosition.distanceTo(state.position) * 100;
      }
    }).toList();
  }

  List<double> yAngularValues(final InstructionResult res, final List<InnerOuterRobiState> states, final YAxisType yAxis, final bool angular) {
    return states.map((state) {
      double y = 0;

      switch (yAxis) {
        case YAxisType.position:
          y = state.rotation;
          break;
        case YAxisType.velocity:
          if (res is TurnResult) {
            y = (state.outerVelocity - state.innerVelocity) / widget.robiConfig.trackWidth * (180 / pi);
          } else if (res is RapidTurnResult) {
            y = state.outerVelocity / (widget.robiConfig.trackWidth * pi) * 360;
          }
          break;
        case YAxisType.acceleration:
          if (res is TurnResult) {
            y = (state.outerAcceleration - state.innerAcceleration) / widget.robiConfig.trackWidth * (180 / pi);
          } else if (res is RapidTurnResult) {
            y = state.outerAcceleration / (widget.robiConfig.trackWidth * pi) * 360;
          }
          break;
      }

      return y;
    }).toList();
  }

  List<double> yOuterValues(final InstructionResult res, final List<InnerOuterRobiState> states, final YAxisType yAxis) {
    return states.map((state) {
      double y = 0;

      switch (yAxis) {
        case YAxisType.position:
          y = state.position.distanceTo(res.startPosition);
          break;
        case YAxisType.velocity:
          y = state.outerVelocity;
          break;
        case YAxisType.acceleration:
          y = state.outerAcceleration;
          break;
      }

      return y * 100;
    }).toList();
  }

  List<double> yInnerValues(final InstructionResult res, final List<InnerOuterRobiState> states, final YAxisType yAxis) {
    return states.map((state) {
      double y = 0;

      switch (yAxis) {
        case YAxisType.position:
          y = state.position.distanceTo(res.startPosition);
          break;
        case YAxisType.velocity:
          y = state.innerVelocity;
          break;
        case YAxisType.acceleration:
          y = state.innerAcceleration;
          break;
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
  position,
  velocity,
  acceleration,
}
