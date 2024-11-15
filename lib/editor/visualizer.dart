import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_pilot/editor/painters/ir_read_painter.dart';
import 'package:path_pilot/editor/painters/line_painter.dart';
import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:path_pilot/editor/painters/timeline_painter.dart';
import 'package:path_pilot/robi_api/ir_read_api.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

class InstructionsVisualizer extends Visualizer {
  const InstructionsVisualizer({
    super.key,
    required super.scale,
    required super.offset,
    required super.robiConfig,
    required super.lockToRobi,
    required super.robiState,
    required super.totalTime,
    required super.highlightedInstruction,
    required SimulationResult simulationResult,
    required super.time,
    required super.onScaleChanged,
    required super.onOffsetChanged,
    required super.onLockToRobiChanged,
    required super.onTimeChanged,
    super.enableTimeInput,
  }) : super(
          simulationResult: simulationResult,
          robiStateType: RobiStateType.innerOuter,
        );
}

class IrVisualizer extends Visualizer {
  const IrVisualizer({
    super.key,
    required super.scale,
    required super.offset,
    required super.robiConfig,
    required super.lockToRobi,
    required super.robiState,
    required super.totalTime,
    required IrCalculatorResult irCalculatorResult,
    required super.irPathApproximation,
    required IrReadPainterSettings irReadPainterSettings,
    required super.time,
    super.enableTimeInput = true,
    required super.onScaleChanged,
    required super.onOffsetChanged,
    required super.onLockToRobiChanged,
    required super.onTimeChanged,
  }) : super(
          irReadPainterSettings: irReadPainterSettings,
          irCalculatorResult: irCalculatorResult,
          robiStateType: RobiStateType.leftRight,
        );
}

class Visualizer extends StatelessWidget {
  final double totalTime;
  final RobiConfig robiConfig;
  final bool enableTimeInput;
  final RobiStateType robiStateType;
  final RobiState robiState;

  // For InstructionsVisualizer
  final SimulationResult? simulationResult;
  final InstructionResult? highlightedInstruction;

  // For IrVisualizer
  final IrReadPainterSettings? irReadPainterSettings;
  final IrCalculatorResult? irCalculatorResult;
  final List<Vector2>? irPathApproximation;

  final double scale;
  final void Function(double newScale) onScaleChanged;

  final Offset offset;
  final void Function(Offset newOffset) onOffsetChanged;

  final bool lockToRobi;
  final void Function(bool newLockToRobi) onLockToRobiChanged;

  final double time;
  final void Function(double newTime, Offset newOffset) onTimeChanged;

  static const double minScale = 6;
  static const double maxScale = 12;

  const Visualizer({
    super.key,
    required this.scale,
    required this.offset,
    required this.robiConfig,
    required this.lockToRobi,
    required this.totalTime,
    required this.robiStateType,
    required this.robiState,
    required this.time,
    required this.onScaleChanged,
    required this.onOffsetChanged,
    required this.onLockToRobiChanged,
    required this.onTimeChanged,
    this.enableTimeInput = true,
    this.simulationResult,
    this.irReadPainterSettings,
    this.highlightedInstruction,
    this.irCalculatorResult,
    this.irPathApproximation,
  });

  @override
  Widget build(BuildContext context) {
    Offset newOffset = offset;
    if (lockToRobi) {
      newOffset = Offset(-robiState.position.x, robiState.position.y) * (pow(2, scale) - 1);
    }

    return Column(
      children: [
        Expanded(
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                final newScale = (scale - event.scrollDelta.dy / 500).clamp(minScale, maxScale);
                onScaleChanged(newScale);
              }
            },
            child: GestureDetector(
              onPanUpdate: (details) => onOffsetChanged(newOffset + details.delta),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: LinePainter(
                    robiStateType: robiStateType,
                    robiState: robiState,
                    scale: pow(2, scale) - 1,
                    robiConfig: robiConfig,
                    simulationResult: simulationResult,
                    irReadPainterSettings: irReadPainterSettings,
                    highlightedInstruction: highlightedInstruction,
                    irCalculatorResult: irCalculatorResult,
                    irPathApproximation: irPathApproximation,
                    offset: newOffset,
                  ),
                  child: Container(),
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const Text("Zoom"),
              Expanded(
                child: Slider(
                  value: scale,
                  min: minScale,
                  max: maxScale,
                  onChanged: (value) => onScaleChanged(value),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text("Time ${printDuration(Duration(milliseconds: (time * 1000).toInt()))} / ${printDuration(Duration(milliseconds: (totalTime * 1000).toInt()))}"),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (simulationResult != null && simulationResult!.instructionResults.length < 10001)
                      Row(
                        children: [
                          const SizedBox(width: 24),
                          Expanded(
                            child: RepaintBoundary(
                              key: ValueKey(simulationResult.hashCode + highlightedInstruction.hashCode),
                              child: CustomPaint(
                                size: const Size.fromHeight(15),
                                painter: TimelinePainter(
                                  simResult: simulationResult!,
                                  highlightedInstruction: highlightedInstruction,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                        ],
                      ),
                    Slider(
                      value: time,
                      onChanged: enableTimeInput ? (value) => onTimeChanged(value, newOffset) : null,
                      max: totalTime,
                      min: 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => onOffsetChanged(Offset.zero),
                label: const Text("Center"),
                icon: const Icon(Icons.center_focus_weak),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => onLockToRobiChanged(!lockToRobi),
                label: const Text("Lock"),
                icon: Icon(lockToRobi ? Icons.check_box : Icons.check_box_outline_blank),
              )
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

String printDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, "0").substring(0, 2);
  String twoDigitMinutes = duration.inMinutes.remainder(60).abs().toString();
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60).abs());
  String twoDigitMilliseconds = twoDigits(duration.inMilliseconds.remainder(1000).abs());
  return "$twoDigitMinutes:$twoDigitSeconds:$twoDigitMilliseconds";
}
