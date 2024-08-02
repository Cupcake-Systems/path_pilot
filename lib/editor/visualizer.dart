import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/ir_read_painter.dart';
import 'package:robi_line_drawer/editor/painters/line_painter.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';

class Visualizer extends StatefulWidget {
  final SimulationResult simulationResult;
  final double scale;
  final void Function(double scale) scaleChanged;
  final RobiConfig robiConfig;
  final IrReadResult? irReadResult;
  final IrReadPainterSettings irReadPainterSettings;
  final InstructionResult? highlightedInstruction;

  const Visualizer({
    super.key,
    required this.simulationResult,
    required this.scale,
    required this.scaleChanged,
    required this.robiConfig,
    this.irReadResult,
    required this.irReadPainterSettings,
    required this.highlightedInstruction,
  });

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer> {
  late var simulationResult = widget.simulationResult;
  late double scale = widget.scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          AppBar(title: const Text("Visual Editor")),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(
                  painter: LinePainter(
                    scale: scale,
                    robiConfig: widget.robiConfig,
                    irReadResult: widget.irReadResult,
                    simulationResult: widget.simulationResult,
                    irReadPainterSettings: widget.irReadPainterSettings,
                    highlightedInstruction: widget.highlightedInstruction,
                  ),
                  child: Container(),
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
                  min: 25,
                  max: 400,
                  onChanged: (double value) {
                    setState(() => scale = value);
                    widget.scaleChanged(scale);
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text("${(scale).round()}%", textAlign: TextAlign.center),
              ),
            ],
          )
        ],
      ),
    );
  }
}
