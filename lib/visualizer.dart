import 'dart:async';

import 'package:flutter/material.dart';
import 'package:robi_line_drawer/line_painter.dart';
import 'package:robi_line_drawer/robi_utils.dart';

class MyEvent {
  final List<MissionInstruction> instructions;

  const MyEvent(this.instructions);
}

class EventListener {
  final StreamController<MyEvent> _controller =
      StreamController<MyEvent>.broadcast();

  Stream<MyEvent> get eventStream => _controller.stream;

  void fireEvent(List<MissionInstruction> instructions) =>
      _controller.add(MyEvent(instructions));

  void dispose() => _controller.close();
}

class Visualizer extends StatefulWidget {
  final List<MissionInstruction> initialInstructions;
  final EventListener listener;
  final RobiConfig robiConfig;

  const Visualizer({
    super.key,
    required this.initialInstructions,
    required this.listener,
    required this.robiConfig,
  });

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer> {
  late List<MissionInstruction> instructions = widget.initialInstructions;
  double scale = 100;

  @override
  void initState() {
    super.initState();
    widget.listener.eventStream
        .listen((event) => setState(() => instructions = event.instructions));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          AppBar(title: const Text("Visual Editor")),
          Expanded(
            child: Center(
              child: CustomPaint(
                painter: LinePainter(instructions, scale, widget.robiConfig),
              ),
            ),
          ),
          Row(
            children: [
              const Text("Zoom: "),
              Expanded(
                child: Slider(
                  value: scale,
                  min: 1,
                  max: 200,
                  onChanged: (double value) {
                    setState(() {
                      scale = value;
                    });
                  },
                ),
              ),
              SizedBox(width: 40, child: Text("${(scale).round()}%", textAlign: TextAlign.center)),
            ],
          )
        ],
      ),
    );
  }
}
