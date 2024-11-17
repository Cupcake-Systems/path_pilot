import 'package:flutter/material.dart';
import 'package:path_pilot/editor/editor.dart';
import 'package:path_pilot/editor/ir_visualizer/ir_readings_visualizer.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../robi_api/ir_read_api.dart';
import '../../robi_api/robi_utils.dart';

class IrReadingInfoWidget extends StatelessWidget {
  final IrReadResult irReadResult;
  final IrCalculatorResult irCalculatorResult;
  final RobiConfig selectedRobiConfig;

  const IrReadingInfoWidget({
    super.key,
    required this.irReadResult,
    required this.irCalculatorResult,
    required this.selectedRobiConfig,
  });

  @override
  Widget build(BuildContext context) {
    double leftTravelDistance = 0, rightTravelDistance = 0;

    Vector2 lastLeftPos = Vector2.zero(), lastRightPos = Vector2.zero();

    for (final wheelPositions in irCalculatorResult.wheelPositions) {
      leftTravelDistance += lastLeftPos.distanceTo(wheelPositions.$1);
      rightTravelDistance += lastRightPos.distanceTo(wheelPositions.$2);

      lastLeftPos = wheelPositions.$1;
      lastRightPos = wheelPositions.$2;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("IR Reading", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("${irReadResult.measurements.length} readings"),
            Text("${irReadResult.resolution}s between each reading"),
            Text("Left track length: ${roundToDigits(leftTravelDistance, 2)}m"),
            Text("Right track length: ${roundToDigits(rightTravelDistance, 2)}m"),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => IrReadingsVisualizer(irReadResult: irReadResult, robiConfig: selectedRobiConfig),
                ));
              },
              label: const Text("View readings"),
              icon: const Icon(Icons.remove_red_eye),
            ),
          ],
        ),
      ),
    );
  }
}
