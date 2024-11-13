import 'package:flutter/material.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';

class IrReadingsVisualizer extends StatelessWidget {
  final IrReadResult irReadResult;
  final RobiConfig robiConfig;

  const IrReadingsVisualizer({super.key, required this.irReadResult, required this.robiConfig});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("IR Readings"),
      ),
      body: irReadResult.measurements.isEmpty
          ? const Center(child: Text("No Readings"))
          : ListView.builder(
              itemCount: irReadResult.measurements.length,
              prototypeItem: IrMeasurementWidget(irReadResult: irReadResult, index: 0, robiConfig: robiConfig),
              itemBuilder: (context, index) {
                return IrMeasurementWidget(irReadResult: irReadResult, index: index, robiConfig: robiConfig);
              },
            ),
    );
  }
}

class IrMeasurementWidget extends StatelessWidget {
  final IrReadResult irReadResult;
  final int index;
  final RobiConfig robiConfig;

  const IrMeasurementWidget({super.key, required this.irReadResult, required this.index, required this.robiConfig});

  @override
  Widget build(BuildContext context) {
    final measurement = irReadResult.measurements[index];

    final leftVel = freqToVel(measurement.motorLeftFreq, robiConfig.wheelRadius)  * (measurement.leftFwd ? 1 : -1);
    final rightVel = freqToVel(measurement.motorRightFreq, robiConfig.wheelRadius) * (measurement.rightFwd ? 1 : -1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${index + 1}. IR Measurement at ${(irReadResult.resolution * index).toStringAsFixed(2)}s", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              children: [
                TableRow(
                  children: [
                    const Text("IR Readings (Raw):    "),
                    Text("${measurement.leftIr} | ${measurement.middleIr} | ${measurement.rightIr}"),
                  ]
                ),
                TableRow(
                  children: [
                    const Text("Motor Speeds:    "),
                    Text("${measurement.motorLeftFreq} Hz (${(leftVel * 100).toStringAsFixed(2)}cm/s) | ${measurement.motorRightFreq} Hz (${(rightVel * 100).toStringAsFixed(2)}cm/s)"),
                  ]
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
