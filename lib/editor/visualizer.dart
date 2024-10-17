import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/ir_read_painter.dart';
import 'package:robi_line_drawer/editor/painters/line_painter.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

class Visualizer extends StatefulWidget {
  final SimulationResult simulationResult;
  final double scale;
  final void Function(double scale, Offset offset) transformChanged;
  final RobiConfig robiConfig;
  final IrReadPainterSettings irReadPainterSettings;
  final InstructionResult? highlightedInstruction;
  final IrCalculatorResult? irCalculatorResult;
  final List<Vector2>? irPathApproximation;
  final Offset offset;

  const Visualizer({
    super.key,
    required this.simulationResult,
    required this.scale,
    required this.offset,
    required this.transformChanged,
    required this.robiConfig,
    required this.irReadPainterSettings,
    required this.highlightedInstruction,
    this.irCalculatorResult,
    this.irPathApproximation,
  });

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer> {
  late final Timer _timer;

  late double scale = widget.scale;
  late Offset _offset = widget.offset;
  late Offset _previousOffset = widget.offset;
  double t = 0;
  bool updateRobi = false;

  static const double minScale = 6;
  static const double maxScale = 12;
  static const double robiDrawerUpdateRate = 1 / 30;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(Duration(milliseconds: (robiDrawerUpdateRate * 1000).round()), (timer) {
      if (!mounted || !updateRobi) return;

      setState(() {
        t += robiDrawerUpdateRate;
        if (t >= widget.simulationResult.totalTime) {
          t = widget.simulationResult.totalTime;
          updateRobi = false;
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRect(
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  double newScale = scale - event.scrollDelta.dy / 100;
                  if (newScale > maxScale) {
                    newScale = maxScale;
                  } else if (newScale < minScale) {
                    newScale = minScale;
                  }
                  setState(() => scale = newScale);
                }
              },
              child: GestureDetector(
                onHorizontalDragStart: (details) {
                  _previousOffset = details.localPosition - _offset;
                  widget.transformChanged(scale, _offset);
                },
                onHorizontalDragUpdate: (details) => setState(() {
                  _offset = details.localPosition - _previousOffset;
                  widget.transformChanged(scale, _offset);
                }),
                child: CustomPaint(
                  painter: LinePainter(
                    t: t,
                    scale: pow(2, scale) - 1,
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
                  value: scale,
                  min: minScale,
                  max: maxScale,
                  onChanged: (double value) {
                    setState(() => scale = value);
                    widget.transformChanged(scale, _offset);
                  },
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _offset = Offset.zero);
                  widget.transformChanged(scale, _offset);
                },
                label: const Text("Center"),
                icon: const Icon(Icons.center_focus_weak),
              )
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const Text("Time"),
              Expanded(
                child: Slider(
                  value: t,
                  onChanged: (value) {
                    setState(() {
                      t = value;
                      updateRobi = false;
                    });
                  },
                  max: widget.simulationResult.totalTime,
                  min: 0,
                ),
              ),
              SizedBox(
                width: 116,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      updateRobi = !updateRobi;
                      if (updateRobi && t == widget.simulationResult.totalTime) {
                        t = 0;
                      }
                    });
                  },
                  label: Text(updateRobi ? "Pause" : "Play"),
                  icon: Icon(updateRobi ? Icons.pause : Icons.play_arrow),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
