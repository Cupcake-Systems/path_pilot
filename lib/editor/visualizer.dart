import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/app_storage.dart';
import 'package:robi_line_drawer/editor/painters/ir_read_painter.dart';
import 'package:robi_line_drawer/editor/painters/line_painter.dart';
import 'package:robi_line_drawer/editor/painters/robi_painter.dart';
import 'package:robi_line_drawer/editor/painters/timeline_painter.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

class InstructionsVisualizer extends Visualizer {
  const InstructionsVisualizer({
    super.key,
    required super.scale,
    required super.offset,
    required super.transformChanged,
    required super.robiConfig,
    required super.lockToRobi,
    required super.getStateAtTime,
    required super.totalTime,
    required super.highlightedInstruction,
    required SimulationResult simulationResult,
    super.timeOffset = 0,
    super.enableTimeInput = true,
  }) : super(
          simulationResult: simulationResult,
        );
}

class IrVisualizer extends Visualizer {
  const IrVisualizer({
    super.key,
    required super.scale,
    required super.offset,
    required super.transformChanged,
    required super.robiConfig,
    required super.lockToRobi,
    required super.getStateAtTime,
    required super.totalTime,
    required super.irCalculatorResult,
    required super.irPathApproximation,
    required IrReadPainterSettings irReadPainterSettings,
    super.timeOffset = 0,
    super.enableTimeInput = true,
  }) : super(
          irReadPainterSettings: irReadPainterSettings,
        );
}

class Visualizer extends StatefulWidget {
  final double scale, totalTime;
  final void Function(double zoom, Offset offset, bool lockToRobi) transformChanged;
  final RobiConfig robiConfig;
  final IrReadPainterSettings? irReadPainterSettings;
  final InstructionResult? highlightedInstruction;
  final IrCalculatorResult? irCalculatorResult;
  final List<Vector2>? irPathApproximation;
  final Offset offset;
  final bool lockToRobi;
  final RobiState Function(double t) getStateAtTime;
  final SimulationResult? simulationResult;
  final double timeOffset;
  final bool enableTimeInput;

  const Visualizer({
    super.key,
    required this.scale,
    required this.offset,
    required this.transformChanged,
    required this.robiConfig,
    this.irReadPainterSettings,
    this.highlightedInstruction,
    this.irCalculatorResult,
    this.irPathApproximation,
    required this.lockToRobi,
    required this.getStateAtTime,
    required this.totalTime,
    this.simulationResult,
    this.timeOffset = 0,
    this.enableTimeInput = true,
  });

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer> {
  late double zoom = widget.scale;
  late Offset _offset = widget.offset;
  late Offset _previousOffset = widget.offset;
  late bool lockToRobi = widget.lockToRobi;

  bool updateRobi = false;

  static const double minScale = 6;
  static const double maxScale = 12;

  Stopwatch sw = Stopwatch();
  double timeOffset = 0;

  @override
  Widget build(BuildContext context) {
    final robiDrawerUpdateRate = 1 / SettingsStorage.visualizerFps;

    Future.delayed(Duration(milliseconds: (robiDrawerUpdateRate * 1000).round())).then(
      (value) {
        if (!mounted || !updateRobi) return;
        setState(() {});
      },
    );

    if (!widget.enableTimeInput) timeOffset = widget.timeOffset;
    double timeSnapshot = timeOffset + sw.elapsedMilliseconds / 1000;

    if (timeSnapshot >= widget.totalTime) {
      pause();
      timeSnapshot = widget.totalTime;
    }

    final robiState = widget.getStateAtTime(timeSnapshot);

    if (lockToRobi) {
      _offset = Offset(-robiState.position.x, robiState.position.y) * (pow(2, zoom) - 1);
    }

    return Column(
      children: [
        Expanded(
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                double newScale = zoom - event.scrollDelta.dy / 500;
                newScale = newScale.clamp(minScale, maxScale);
                changeZoom(newScale);
              }
            },
            child: GestureDetector(
              onHorizontalDragStart: (details) {
                _previousOffset = details.localPosition - _offset;
                lockToRobi = false;
                widget.transformChanged(zoom, _offset, lockToRobi);
              },
              onHorizontalDragUpdate: (details) => setState(() {
                _offset = details.localPosition - _previousOffset;
                lockToRobi = false;
                widget.transformChanged(zoom, _offset, lockToRobi);
              }),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: LinePainter(
                    robiState: robiState,
                    scale: pow(2, zoom) - 1,
                    robiConfig: widget.robiConfig,
                    simulationResult: widget.simulationResult,
                    irReadPainterSettings: widget.irReadPainterSettings,
                    highlightedInstruction: widget.highlightedInstruction,
                    irCalculatorResult: widget.irCalculatorResult,
                    irPathApproximation: widget.irPathApproximation,
                    offset: _offset,
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
                  value: zoom,
                  min: minScale,
                  max: maxScale,
                  onChanged: (value) => changeZoom(value),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text("Time ${_printDuration(Duration(milliseconds: (timeSnapshot * 1000).toInt()))} / ${_printDuration(Duration(milliseconds: (widget.totalTime * 1000).toInt()))}"),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.simulationResult != null && widget.simulationResult!.instructionResults.length < 10001)
                      Row(
                        children: [
                          const SizedBox(width: 24),
                          Expanded(
                            child: RepaintBoundary(
                              key: ValueKey(widget.simulationResult.hashCode + widget.highlightedInstruction.hashCode),
                              child: CustomPaint(
                                size: const Size.fromHeight(15),
                                painter: TimelinePainter(
                                  simResult: widget.simulationResult!,
                                  highlightedInstruction: widget.highlightedInstruction,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                        ],
                      ),
                    Slider(
                      value: timeSnapshot,
                      onChanged: (value) {
                        setState(() {
                          pause();
                          timeOffset = value;
                          sw.reset();
                        });
                      },
                      max: widget.totalTime,
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
                onPressed: () {
                  setState(() {
                    if (updateRobi) {
                      pause();
                    } else {
                      resume();
                    }
                    if (updateRobi && timeSnapshot >= widget.totalTime) {
                      sw.reset();
                      timeOffset = 0;
                    }
                  });
                },
                label: Text(updateRobi ? "Pause" : "Play"),
                icon: Icon(updateRobi ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _offset = Offset.zero;
                    lockToRobi = false;
                  });
                  widget.transformChanged(zoom, _offset, lockToRobi);
                },
                label: const Text("Center"),
                icon: const Icon(Icons.center_focus_weak),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    lockToRobi = !lockToRobi;
                  });
                  widget.transformChanged(zoom, _offset, lockToRobi);
                },
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

  void changeZoom(double newZoom) {
    setState(() {
      _offset = _offset * pow(2, newZoom - zoom).toDouble();
      zoom = newZoom;
    });

    widget.transformChanged(zoom, _offset, lockToRobi);
  }

  void resume() {
    updateRobi = true;
    sw.start();
  }

  void pause() {
    updateRobi = false;
    sw.stop();
  }
}

String _printDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, "0").substring(0, 2);
  String twoDigitMinutes = duration.inMinutes.remainder(60).abs().toString();
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60).abs());
  String twoDigitMilliseconds = twoDigits(duration.inMilliseconds.remainder(1000).abs());
  return "$twoDigitMinutes:$twoDigitSeconds:$twoDigitMilliseconds";
}
