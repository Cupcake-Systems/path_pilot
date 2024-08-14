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
  late var simulationResult = widget.simulationResult;
  late double scale = widget.scale;
  late Offset _offset = widget.offset;
  late Offset _previousOffset = widget.offset;

  static const double minScale = 6;
  static const double maxScale = 12;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
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
          ),
          Row(
            children: [
              const Text("Zoom: "),
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
              ElevatedButton(
                onPressed: () {
                  setState(() => _offset = Offset.zero);
                  widget.transformChanged(scale, _offset);
                },
                child: const Text("Center"),
              )
            ],
          ),
        ],
      ),
    );
  }
}
