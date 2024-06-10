import 'package:flutter/material.dart';
import 'package:robi_line_drawer/line_painter.dart';
import 'package:robi_line_drawer/robi_utils.dart';

class Visualizer extends StatefulWidget {
  final SimulationResult simulationResult;
  final double scale;
  final void Function(double scale) scaleChanged;
  final RobiConfig robiConfig;

  const Visualizer({
    super.key,
    required this.simulationResult,
    required this.scale,
    required this.scaleChanged,
    required this.robiConfig,
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
                    scale,
                    simulationResult,
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
                  max: 200,
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
