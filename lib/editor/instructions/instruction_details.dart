import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_pilot/editor/editor.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';

import '../painters/robi_painter.dart';

class InstructionDetailsWidget extends StatefulWidget {
  final InstructionResult instructionResult;
  final RobiConfig robiConfig;
  final TimeChangeNotifier timeChangeNotifier;

  const InstructionDetailsWidget({
    super.key,
    required this.instructionResult,
    required this.robiConfig,
    required this.timeChangeNotifier,
  });

  @override
  State<InstructionDetailsWidget> createState() => _InstructionDetailsWidgetState();
}

class _InstructionDetailsWidgetState extends State<InstructionDetailsWidget> {
  static const iterations = 100;

  late XAxisType xAxisMode = widget.instructionResult is RapidTurnResult ? XAxisType.time : XAxisType.position;
  YAxisType yAxisMode = YAxisType.velocity;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    bool isScreenWide = screenSize.width > screenSize.height;

    final List<InnerOuterRobiState> chartStates = List.generate(
      iterations,
      (i) => getRobiStateAtTimeInInstructionResult(
        widget.instructionResult,
        i / (iterations - 1) * widget.instructionResult.totalTime,
      ),
      growable: false,
    );

    late final String xAxisTitle;
    late final String yAxisTitle;

    final angular = widget.instructionResult is! DriveResult;

    switch (xAxisMode) {
      case XAxisType.time:
        xAxisTitle = "Time in s";
        break;
      case XAxisType.position:
        if (angular) {
          xAxisTitle = "Rotation in °";
        } else {
          xAxisTitle = "Distance driven in cm";
        }
        break;
    }

    switch (yAxisMode) {
      case YAxisType.position:
        if (angular) {
          yAxisTitle = "Rotation in °";
        } else {
          yAxisTitle = "Distance driven in cm";
        }
        break;
      case YAxisType.velocity:
        yAxisTitle = "Velocity in ${angular ? "°/s" : "cm/s"}";
        break;
      case YAxisType.acceleration:
        yAxisTitle = "Acceleration in ${angular ? "°/s²" : "cm/s²"}";
        break;
    }

    final xSpots = xValues(
      widget.instructionResult,
      chartStates,
      xAxisMode,
    );

    final ySpots = angular
        ? yAngularValues(
            widget.instructionResult,
            chartStates,
            yAxisMode,
          )
        : yDriveResValues(
            widget.instructionResult as DriveResult,
            chartStates,
            yAxisMode,
          );

    final spots = mergeData(xSpots, ySpots);

    double minY = 0;
    double maxX = 0;

    switch (xAxisMode) {
      case XAxisType.time:
        maxX = widget.instructionResult.totalTime;
        break;
      case XAxisType.position:
        if (angular) {
          if (widget.instructionResult is RapidTurnResult) {
            maxX = (widget.instructionResult as RapidTurnResult).totalTurnDegree;
          } else {
            maxX = (widget.instructionResult as TurnResult).totalTurnDegree;
          }
        } else {
          maxX = (widget.instructionResult as DriveResult).totalDistance * 100;
        }
        break;
    }

    if (spots.isNotEmpty) {
      minY = spots.map((spot) => spot.y).reduce(min);
    }
    if (minY > 0) {
      minY = 0;
    }

    return IntrinsicHeight(
      child: Flex(
        direction: isScreenWide ? Axis.horizontal : Axis.vertical,
        children: [
          Flexible(
            fit: FlexFit.tight,
            child: AspectRatio(
              aspectRatio: 1.5,
              child: ListenableBuilder(
                builder: (context, child) {
                  double? progress = (widget.timeChangeNotifier.time - widget.instructionResult.timeStamp) / widget.instructionResult.totalTime;
                  if (progress > 1 || progress < 0) progress = null;
                  return LineChart(
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
                          sideTitles: const SideTitles(showTitles: true, reservedSize: 40, maxIncluded: false, minIncluded: false),
                        ),
                        bottomTitles: AxisTitles(
                          axisNameWidget: Text(xAxisTitle),
                          axisNameSize: 20,
                          sideTitles: const SideTitles(showTitles: true, reservedSize: 30, maxIncluded: false, minIncluded: true),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          isStepLineChart: yAxisMode == YAxisType.acceleration,
                          spots: spots,
                          color: Colors.grey,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                      extraLinesData: progress == null
                          ? null
                          : ExtraLinesData(
                              verticalLines: [
                                VerticalLine(
                                  x: getProgressIndicatorX(progress, maxX),
                                  color: Colors.grey,
                                  dashArray: [5, 5],
                                ),
                              ],
                            ),
                    ),
                  );
                },
                listenable: widget.timeChangeNotifier,
              ),
            ),
          ),
          IntrinsicWidth(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isScreenWide) const SizedBox(height: 20),
                  DropdownMenu<XAxisType>(
                    width: 180,
                    initialSelection: xAxisMode,
                    label: const Text("X-Axis"),
                    onSelected: (value) => setState(() => xAxisMode = value ?? XAxisType.position),
                    dropdownMenuEntries: XAxisType.values.map((e) => e.dropdownMenuEntry).toList(),
                  ),
                  const SizedBox(height: 16),
                  DropdownMenu<YAxisType>(
                    initialSelection: yAxisMode,
                    width: 180,
                    onSelected: (value) => setState(() => yAxisMode = value ?? YAxisType.velocity),
                    label: const Text("Y-Axis"),
                    dropdownMenuEntries: YAxisType.values.map((e) => e.dropdownMenuEntry).toList(),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  double getProgressIndicatorX(final double progress, final double maxX) {
    switch (xAxisMode) {
      case XAxisType.time:
        return progress * maxX;
      case XAxisType.position:
        final rs = getRobiStateAtTimeInInstructionResult(widget.instructionResult, progress * widget.instructionResult.totalTime);
        if (widget.instructionResult is! DriveResult) {
          return rs.rotation - widget.instructionResult.startRotation;
        }
        return rs.position.distanceTo(widget.instructionResult.startPosition) * 100;
    }
  }

  List<double> xValues(final InstructionResult res, final List<InnerOuterRobiState> states, final XAxisType xAxis) {
    return states.map((state) {
      if (xAxis == XAxisType.time) {
        return state.timeStamp - res.timeStamp;
      } else if (res is! DriveResult) {
        return (state.rotation - res.startRotation).abs();
      } else {
        return res.startPosition.distanceTo(state.position) * 100;
      }
    }).toList();
  }

  List<double> yAngularValues(final InstructionResult res, final List<InnerOuterRobiState> states, final YAxisType yAxis) {
    if (res is DriveResult) {
      throw Exception("Cannot use angular values for DriveResult");
    }

    return states.map((state) {
      double y = 0;

      switch (yAxis) {
        case YAxisType.position:
          y = (state.rotation - res.startRotation).abs();
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

  List<double> yDriveResValues(final DriveResult res, final List<InnerOuterRobiState> states, final YAxisType yAxis) {
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

  List<FlSpot> mergeData(final List<double> xValues, final List<double> yValues) => List.generate(
        xValues.length,
        (i) => FlSpot(xValues[i], yValues[i]),
        growable: false,
      );
}

enum XAxisType {

  time("Time"),
  position("Position");

  final String label;

  DropdownMenuEntry<XAxisType> get dropdownMenuEntry => DropdownMenuEntry(value: this, label: label);

  const XAxisType(this.label);
}

enum YAxisType {
  position("Position"),
  velocity("Velocity"),
  acceleration("Acceleration");

  final String label;

  DropdownMenuEntry<YAxisType> get dropdownMenuEntry => DropdownMenuEntry(value: this, label: label);

  const YAxisType(this.label);
}
