import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:robi_line_drawer/main.dart';
import 'package:universal_ble/universal_ble.dart';

const String serviceUuid = "00001234-0000-1000-8000-00805f9b34fb";

class BluetoothConnectWidget extends StatefulWidget {
  const BluetoothConnectWidget({super.key});

  @override
  State<BluetoothConnectWidget> createState() => _BluetoothConnectWidgetState();
}

class _BluetoothConnectWidgetState extends State<BluetoothConnectWidget> {
  HashSet<BleDevice> disconnectedRobiDevices = HashSet(
    equals: (p0, p1) => p0.deviceId == p1.deviceId,
    hashCode: (p0) => p0.deviceId.hashCode,
  );
  HashSet<BleDevice> connectedRobiDevices = HashSet(
    equals: (p0, p1) => p0.deviceId == p1.deviceId,
    hashCode: (p0) => p0.deviceId.hashCode,
  );
  bool isScanning = true;
  AvailabilityState bluetoothState = AvailabilityState.unknown;

  @override
  void initState() {
    super.initState();
    bleConnectionChange["connect_widget"] = (deviceId, connected) {
      if (connected) {
        final d = disconnectedRobiDevices.where((element) => element.deviceId == deviceId);
        if (d.isEmpty) return;
        setState(() {
          connectedRobiDevices.add(d.first);
          disconnectedRobiDevices.remove(d.first);
        });
      } else {
        final d = connectedRobiDevices.where((element) => element.deviceId == deviceId);
        if (d.isEmpty) return;
        setState(() {
          connectedRobiDevices.remove(d.first);
          disconnectedRobiDevices.add(d.first);
        });
      }
    };
    UniversalBle.onAvailabilityChange = (state) {
      if (!mounted) return;
      setState(() => bluetoothState = state);
      if (state == AvailabilityState.poweredOn) {
        startScan();
      } else {
        stopScan();
      }
    };
  }

  @override
  void dispose() {
    super.dispose();
    stopScan();
  }

  Future<void> startScan() async {
    UniversalBle.onScanResult = (bleDevice) async {
      if (await bleDevice.connectionState == BleConnectionState.connected) {
        setState(() => connectedRobiDevices.add(bleDevice));
      } else {
        setState(() => disconnectedRobiDevices.add(bleDevice));
      }
    };

    final systemDevices = await UniversalBle.getSystemDevices(withServices: [serviceUuid]);

    setState(() {
      connectedRobiDevices
        ..clear()
        ..addAll(systemDevices);
      disconnectedRobiDevices.clear();
      isScanning = true;
    });

    UniversalBle.startScan(scanFilter: ScanFilter(withServices: [serviceUuid]));

    Future.delayed(const Duration(seconds: 10)).then((value) => stopScan());
  }

  Future<void> stopScan() async {
    if (!isScanning) return;
    await UniversalBle.stopScan();
    if (mounted) setState(() => isScanning = false);
  }

  @override
  Widget build(BuildContext context) {

    if (bluetoothState != AvailabilityState.poweredOn) {
      return const ListTile(title: Text("Bluetooth not active"));
    }

    return Column(
      children: [
        ListView(
          shrinkWrap: true,
          children: [
            for (final device in connectedRobiDevices) ...[
              ConnectedBluetoothDeviceWidget(device: device),
            ],
            if (connectedRobiDevices.isNotEmpty) const Divider(height: 1),
            for (final device in disconnectedRobiDevices) ...[
              DisconnectedBluetoothDeviceWidget(
                key: ObjectKey(device),
                device: device,
                onConnectClick: stopScan,
              ),
            ],
            if (disconnectedRobiDevices.isNotEmpty) const Divider(height: 1),
            if (isScanning) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()),
                      const SizedBox(width: 10),
                      ElevatedButton(onPressed: stopScan, child: const Text("Stop")),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ElevatedButton.icon(
                    onPressed: startScan,
                    label: const Text("Refresh"),
                    icon: const Icon(Icons.cached),
                  ),
                ),
              )
            ],
          ],
        ),
      ],
    );
  }
}

class DisconnectedBluetoothDeviceWidget extends StatefulWidget {
  final BleDevice device;
  final Future<void> Function() onConnectClick;

  const DisconnectedBluetoothDeviceWidget({super.key, required this.device, required this.onConnectClick});

  @override
  State<DisconnectedBluetoothDeviceWidget> createState() => _DisconnectedBluetoothDeviceWidgetState();
}

class _DisconnectedBluetoothDeviceWidgetState extends State<DisconnectedBluetoothDeviceWidget> {
  bool connecting = false;
  bool connectionFailure = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.device.name ?? "Unknown"),
      subtitle: Text(widget.device.deviceId),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connectionFailure) ...[
            const Card(
              color: Colors.red,
              child: Padding(
                padding: EdgeInsets.all(5),
                child: Text("Failed to connect"),
              ),
            ),
          ],
          ElevatedButton(
            onPressed: connecting
                ? null
                : () async {
                    await widget.onConnectClick();

                    setState(() {
                      connecting = true;
                      connectionFailure = false;
                    });

                    try {
                      await UniversalBle.connect(widget.device.deviceId, connectionTimeout: const Duration(seconds: 5));
                    } on Exception {
                      connectionFailure = true;
                    }
                    setState(() {
                      connecting = false;
                    });
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (connecting) ...[
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()),
                  const SizedBox(width: 10),
                ],
                Text(connectionFailure ? "Retry" : "Connect"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConnectedBluetoothDeviceWidget extends StatefulWidget {
  final BleDevice device;

  const ConnectedBluetoothDeviceWidget({super.key, required this.device});

  @override
  State<ConnectedBluetoothDeviceWidget> createState() => _ConnectedBluetoothDeviceWidgetState();
}

class _ConnectedBluetoothDeviceWidgetState extends State<ConnectedBluetoothDeviceWidget> {
  bool isDisconnecting = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.check),
      ),
      title: Text(widget.device.name ?? "Unknown"),
      subtitle: Text(widget.device.deviceId),
      trailing: ElevatedButton(
        onPressed: isDisconnecting
            ? null
            : () async {
                setState(() => isDisconnecting = true);
                await UniversalBle.disconnect(widget.device.deviceId);
              },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDisconnecting) ...[
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()),
              const SizedBox(width: 10),
            ],
            const Text("Disconnect"),
          ],
        ),
      ),
    );
  }
}
