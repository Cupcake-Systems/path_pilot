import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_pilot/app_storage.dart';
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
    required super.zoom,
    required super.offset,
    required super.robiConfig,
    required super.lockToRobi,
    required super.robiState,
    required super.totalTime,
    required super.highlightedInstruction,
    required SimulationResult simulationResult,
    required super.time,
    required super.onZoomChanged,
    required super.onTimeChanged,
    required super.play,
    required super.onTogglePlay,
    super.enableTimeInput,
  }) : super(
          simulationResult: simulationResult,
          robiStateType: RobiStateType.innerOuter,
        );
}

class IrVisualizer extends Visualizer {
  const IrVisualizer({
    super.key,
    required super.zoom,
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
    required super.onZoomChanged,
    required super.onTimeChanged,
    required super.play,
    required super.onTogglePlay,
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

  final double zoom;
  final void Function(double newZoom, Offset newOffset, bool lockToRobi) onZoomChanged;

  final Offset offset;

  final bool lockToRobi;

  final double time;
  final void Function(double newTime, Offset newOffset) onTimeChanged;

  final bool play;
  final void Function(bool play) onTogglePlay;

  static const double minZoom = 100;
  static const double maxZoom = 1000;
  static final double log2 = log(2);

  static final double minScale = log(minZoom + 1) / log2;
  static final double maxScale = log(maxZoom + 1) / log2;

  const Visualizer({
    super.key,
    required this.zoom,
    required this.offset,
    required this.robiConfig,
    required this.lockToRobi,
    required this.totalTime,
    required this.robiStateType,
    required this.robiState,
    required this.time,
    required this.onZoomChanged,
    required this.onTimeChanged,
    required this.play,
    required this.onTogglePlay,
    this.enableTimeInput = true,
    this.simulationResult,
    this.irReadPainterSettings,
    this.highlightedInstruction,
    this.irCalculatorResult,
    this.irPathApproximation,
  });

  static double startZoom = (minZoom + maxZoom) / 2;
  static Offset startOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {

    final totalTimeString = printDuration(Duration(milliseconds: (totalTime * 1000).toInt()), SettingsStorage.showMilliseconds);
    final timeString = printDuration(Duration(milliseconds: (time * 1000).toInt()), SettingsStorage.showMilliseconds);

    return Column(
      children: [
        Expanded(
          child: Listener(
            onPointerSignal: (event) {
              if (event is! PointerScrollEvent) return;
              final oldScale = log(zoom + 1) / log2;
              final newScale = (oldScale - event.scrollDelta.dy / 250).clamp(minScale, maxScale);
              final newZoom = (pow(2, newScale) - 1).toDouble();
              final scaleDelta = log(newZoom + 1) / log2 - oldScale;
              final newOffset = offset * pow(2, scaleDelta).toDouble();
              onZoomChanged(newZoom, newOffset, lockToRobi);
            },
            child: GestureDetector(
              onScaleStart: (details) {
                startZoom = zoom;
                startOffset = details.localFocalPoint - offset;
              },
              onScaleUpdate: (details) {
                if (details.pointerCount > 1) {
                  final newZoom = (startZoom * details.scale).clamp(minZoom, maxZoom);
                  final scaleDelta = (log(newZoom + 1) - log(zoom + 1)) / log2;
                  final newOffset = offset * pow(2, scaleDelta).toDouble();
                  onZoomChanged(newZoom, newOffset, lockToRobi);
                } else {
                  onZoomChanged(zoom, details.localFocalPoint - startOffset, false);
                }
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: LinePainter(
                    robiStateType: robiStateType,
                    robiState: robiState,
                    scale: zoom,
                    robiConfig: robiConfig,
                    simulationResult: simulationResult,
                    irReadPainterSettings: irReadPainterSettings,
                    highlightedInstruction: highlightedInstruction,
                    irCalculatorResult: irCalculatorResult,
                    irPathApproximation: irPathApproximation,
                    offset: offset,
                  ),
                  child: Container(),
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        if (SettingsStorage.developerMode) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Text("Zoom"),
                Expanded(
                  child: Slider(
                    value: log(zoom + 1) / log2,
                    min: minScale,
                    max: maxScale,
                    onChanged: (value) => onZoomChanged(pow(2, value) - 1, offset, lockToRobi),
                  ),
                ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text("$timeString / $totalTimeString"),
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
                      onChanged: enableTimeInput ? (value) => onTimeChanged(value, offset) : null,
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
                onPressed: () => onTogglePlay(!play),
                label: Text(play ? "Pause" : "Play"),
                icon: Icon(play ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => onZoomChanged(zoom, offset, !lockToRobi),
                label: const Text("Lock"),
                icon: Icon(lockToRobi ? Icons.check_box : Icons.check_box_outline_blank),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => onZoomChanged(zoom, Offset.zero, false),
                label: const Text("Center"),
                icon: const Icon(Icons.center_focus_weak),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

String printDuration(Duration duration, bool showMilliseconds) {
  String twoDigits(int n) => n.toString().padLeft(2, "0").substring(0, 2);
  String twoDigitMinutes = duration.inMinutes.remainder(60).abs().toString();
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60).abs());
  if (!showMilliseconds) return "$twoDigitMinutes:$twoDigitSeconds";
  String twoDigitMilliseconds = twoDigits(duration.inMilliseconds.remainder(1000).abs());
  return "$twoDigitMinutes:$twoDigitSeconds:$twoDigitMilliseconds";
}
