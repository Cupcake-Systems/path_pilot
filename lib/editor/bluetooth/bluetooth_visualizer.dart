import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/ir_visualizer.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:vector_math/vector_math.dart';

import '../../main.dart';
import '../../robi_api/robi_utils.dart';
import 'connect_widget.dart';

class BluetoothVisualizerWidget extends StatefulWidget {
  final RobiConfig robiConfig;
  final void Function(List<Vector2> pathApproximation) onPathCreationClick;

  const BluetoothVisualizerWidget({
    super.key,
    required this.robiConfig,
    required this.onPathCreationClick,
  });

  @override
  State<BluetoothVisualizerWidget> createState() => _BluetoothVisualizerWidgetState();
}

class _BluetoothVisualizerWidgetState extends State<BluetoothVisualizerWidget> {
  bool readBluetoothValues = true;
  IrReadResult? irReadResult;

  @override
  void initState() {
    super.initState();
    bleConnectionChange["editor"] = (deviceId, connected) async {
      readBluetoothValues = true;
      if (!connected) {
        setState(() {
          readBluetoothValues = false;
        });

        return;
      }

      while (readBluetoothValues) {
        late final Uint8List data;
        try {
          data = await UniversalBle.readValue(deviceId, serviceUuid, "00005678-0000-1000-8000-00805f9b34fb");
        } on Exception {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        irReadResult ??= IrReadResult(resolution: 0.1, measurements: []);

        setState(() {
          final measurement = Measurement.fromLine(data.buffer.asByteData());
          irReadResult = IrReadResult(resolution: irReadResult!.resolution, measurements: [
            ...irReadResult!.measurements,
            measurement,
          ]);
        });
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    if (irReadResult == null) {
      return const Center();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IrVisualizerWidget(
          robiConfig: widget.robiConfig,
          onPathCreationClick: widget.onPathCreationClick,
          irReadResult: irReadResult!,
          time: irReadResult!.totalTime,
          enableTimeInput: !readBluetoothValues,
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: ElevatedButton.icon(
            onPressed: () {
              irReadResult = null;
            },
            icon: const Icon(Icons.clear),
            label: const Text("Clear"),
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }
}
