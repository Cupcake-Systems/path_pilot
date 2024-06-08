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
  final EventListener listener;

  const Visualizer({super.key, required this.listener});

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer> {
  List<MissionInstruction> instructions = [];

  @override
  void initState() {
    super.initState();
    widget.listener.eventStream
        .listen((event) => setState(() => instructions = event.instructions));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(2),
        child: CustomPaint(
          painter: LinePainter(instructions, 100, RobiConfig(0.035, 0.147)),
        ),
      ),
    );
  }
}
