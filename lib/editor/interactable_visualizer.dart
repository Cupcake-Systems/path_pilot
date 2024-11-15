import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_pilot/editor/painters/ir_read_painter.dart';
import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:path_pilot/editor/visualizer.dart';
import 'package:path_pilot/robi_api/ir_read_api.dart';
import 'package:vector_math/vector_math.dart';

import '../robi_api/robi_utils.dart';

class InteractableIrVisualizer extends StatefulWidget {
  final bool enableTimeInput;
  final RobiConfig robiConfig;
  final IrCalculatorResult irCalculatorResult;
  final List<Vector2>? irPathApproximation;
  final IrReadPainterSettings irReadPainterSettings;
  final IrReadResult irReadResult;
  final double totalTime;

  const InteractableIrVisualizer({
    super.key,
    required this.enableTimeInput,
    required this.robiConfig,
    required this.irCalculatorResult,
    required this.irPathApproximation,
    required this.irReadPainterSettings,
    required this.totalTime,
    required this.irReadResult,
  });

  @override
  State<InteractableIrVisualizer> createState() => _InteractableIrVisualizerState();
}

class _InteractableIrVisualizerState extends State<InteractableIrVisualizer> {
  double scale = 10;
  Offset offset = Offset.zero;
  Offset dragStartOffset = Offset.zero;
  bool lockToRobi = false;
  double time = 0;

  @override
  Widget build(BuildContext context) {
    return IrVisualizer(
      scale: scale,
      offset: offset,
      robiConfig: widget.robiConfig,
      lockToRobi: lockToRobi,
      totalTime: widget.totalTime,
      robiState: getStateAtTime(widget.irCalculatorResult, time),
      time: time,
      onScaleChanged: (newScale) => setState(() {
        offset = offset * pow(2, newScale - scale).toDouble();
        scale = newScale;
      }),
      onOffsetChanged: (newOffset) => setState(() {
        offset = newOffset;
        lockToRobi = false;
      }),
      onLockToRobiChanged: (newLockToRobi) => setState(() => lockToRobi = newLockToRobi),
      onTimeChanged: (newTime, newOffset) => setState(() {
        time = newTime;
        offset = newOffset;
      }),
      irCalculatorResult: widget.irCalculatorResult,
      irPathApproximation: widget.irPathApproximation,
      irReadPainterSettings: widget.irReadPainterSettings,
    );
  }

  RobiState getStateAtTime(IrCalculatorResult irCalcResult, final double t) {
    final res = widget.irReadResult.resolution;
    final states = irCalcResult.robiStates;

    if (states.isEmpty) {
      return RobiState.zero;
    } else if (states.length == 1) {
      return states.first;
    }

    for (int i = 0; i < states.length - 1; ++i) {
      if (t <= res * (i + 1)) {
        return states[i].interpolate(states[i + 1], (t - (res * i)) / res);
      }
    }

    return states.last;
  }
}

class InteractableInstructionsVisualizer extends StatefulWidget {
  final RobiConfig robiConfig;
  final double totalTime;
  final InstructionResult? highlightedInstruction;
  final SimulationResult simulationResult;

  final void Function(double newTime)? onTimeChanged;
  final double? time;

  const InteractableInstructionsVisualizer({
    super.key,
    required this.robiConfig,
    required this.totalTime,
    required this.simulationResult,
    this.highlightedInstruction,
    this.onTimeChanged,
    this.time,
  });

  @override
  State<InteractableInstructionsVisualizer> createState() => _InteractableInstructionsVisualizerState();
}

class _InteractableInstructionsVisualizerState extends State<InteractableInstructionsVisualizer> {
  double scale = 10;
  Offset offset = Offset.zero;
  Offset dragStartOffset = Offset.zero;
  bool lockToRobi = false;
  double time = 0;

  @override
  Widget build(BuildContext context) {
    final selectedTime = widget.time ?? time;

    return InstructionsVisualizer(
      scale: scale,
      offset: offset,
      robiConfig: widget.robiConfig,
      lockToRobi: lockToRobi,
      robiState: widget.simulationResult.getStateAtTime(selectedTime),
      totalTime: widget.totalTime,
      highlightedInstruction: widget.highlightedInstruction,
      simulationResult: widget.simulationResult,
      time:  selectedTime,
      onScaleChanged: (newScale) => setState(() {
        offset = offset * pow(2, newScale - scale).toDouble();
        scale = newScale;
      }),
      onOffsetChanged: (newOffset) => setState(() {
        offset = newOffset;
        lockToRobi = false;
      }),
      onLockToRobiChanged: (newLockToRobi) => setState(() => lockToRobi = newLockToRobi),
      onTimeChanged: (newTime, newOffset) {
        if (widget.onTimeChanged == null) {
          setState(() {
            time = newTime;
            offset = newOffset;
          });
        } else {
          offset = newOffset;
          widget.onTimeChanged!(newTime);
        }
      },
    );
  }
}
