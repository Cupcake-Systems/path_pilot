import 'package:flutter/material.dart';
import 'package:path_pilot/robi_api/ir_read_api.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';

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

    final leftVel = freqToVel(measurement.motorLeftFreq, robiConfig.wheelRadius) * (measurement.leftFwd ? 1 : -1);
    final rightVel = freqToVel(measurement.motorRightFreq, robiConfig.wheelRadius) * (measurement.rightFwd ? 1 : -1);

    final leftGrey = (measurement.leftIr / 1024 * 255).toInt();
    final middleGrey = (measurement.middleIr / 1024 * 255).toInt();
    final rightGrey = (measurement.rightIr / 1024 * 255).toInt();

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
                TableRow(children: [
                  const Text("IR Readings (Raw):    "),
                  Row(
                    children: [
                      Text("L: ${measurement.leftIr} "),
                      Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(leftGrey, leftGrey, leftGrey, 1),
                          borderRadius: BorderRadius.circular(7.5),
                        ),
                      ),
                      Text("   M: ${measurement.middleIr} "),
                      Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(middleGrey, middleGrey, middleGrey, 1),
                          borderRadius: BorderRadius.circular(7.5),
                        ),
                      ),
                      Text("   R: ${measurement.rightIr} "),
                      Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(rightGrey, rightGrey, rightGrey, 1),
                          borderRadius: BorderRadius.circular(7.5),
                        ),
                      ),
                    ],
                  )
                ]),
                TableRow(children: [
                  const Text("Motor Speeds:    "),
                  Text("L: ${measurement.motorLeftFreq} Hz (${(leftVel * 100).toStringAsFixed(2)}cm/s)   R: ${measurement.motorRightFreq} Hz (${(rightVel * 100).toStringAsFixed(2)}cm/s)"),
                ])
              ],
            )
          ],
        ),
      ),
    );
  }
}
