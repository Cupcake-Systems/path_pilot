import 'package:flutter/material.dart';

import '../painters/ir_read_painter.dart';

const defaultIrReadPainterSettings = IrReadPainterSettings(
  irReadingsThreshold: 1024,
  showCalculatedPath: true,
  showTracks: false,
  ramerDouglasPeuckerTolerance: 0.5,
  irInclusionThreshold: 100,
);

class IrPathApproximationSettingsWidget extends StatelessWidget {
  final void Function(IrReadPainterSettings newSettings) onSettingsChange;
  final IrReadPainterSettings settings;

  const IrPathApproximationSettingsWidget({
    super.key,
    required this.onSettingsChange,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final irInclusionThresholdKey = GlobalKey<TooltipState>();
    final ramerDouglasPeuckerToleranceKey = GlobalKey<TooltipState>();
    final irReadingsThresholdKey = GlobalKey<TooltipState>();

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Visibility Settings",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Customize what elements to display on the visualization.",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text("Show wheel track", style: TextStyle(fontSize: 16)),
                  value: settings.showTracks,
                  onChanged: (value) => onSettingsChange(settings.copyWith(showTracks: value)),
                ),
                CheckboxListTile(
                  title: const Text("Show calculated path", style: TextStyle(fontSize: 16)),
                  value: settings.showCalculatedPath,
                  onChanged: (value) => onSettingsChange(
                    settings.copyWith(showCalculatedPath: value),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Tooltip(
                    message: "Show only IR readings below this threshold",
                    key: irReadingsThresholdKey,
                    triggerMode: TooltipTriggerMode.manual,
                    child: const Text("Show only IR readings below threshold", style: TextStyle(fontSize: 16)),
                  ),
                  trailing: IconButton(
                    onPressed: () => irReadingsThresholdKey.currentState?.ensureTooltipVisible(),
                    icon: const Icon(Icons.info),
                  ),
                ),
                Slider(
                  value: settings.irReadingsThreshold.toDouble(),
                  onChanged: (value) => onSettingsChange(settings.copyWith(irReadingsThreshold: value.round())),
                  min: 0,
                  max: 1024,
                  label: settings.irReadingsThreshold.toString(),
                  divisions: 1024,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Path Approximation Settings",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Configure the parameters for approximating the path based on sensor data.",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Tooltip(
                    message: "Adjust the tolerance level for the Ramer-Douglas-Peucker algorithm.",
                    key: ramerDouglasPeuckerToleranceKey,
                    triggerMode: TooltipTriggerMode.manual,
                    child: const Text("Ramer-Douglas-Peucker tolerance", style: TextStyle(fontSize: 16)),
                  ),
                  trailing: IconButton(
                    onPressed: () => ramerDouglasPeuckerToleranceKey.currentState?.ensureTooltipVisible(),
                    icon: const Icon(Icons.info),
                  ),
                ),
                Slider(
                  value: settings.ramerDouglasPeuckerTolerance,
                  onChanged: (value) {
                    onSettingsChange(settings.copyWith(ramerDouglasPeuckerTolerance: value));
                  },
                  min: 0,
                  max: 5,
                  divisions: 50,
                  label: settings.ramerDouglasPeuckerTolerance.toStringAsFixed(2),
                ),
                ListTile(
                  title: Tooltip(
                    message: "Set the minimum IR reading value required for inclusion in the path.",
                    key: irInclusionThresholdKey,
                    triggerMode: TooltipTriggerMode.manual,
                    child: const Text("IR inclusion threshold", style: TextStyle(fontSize: 16)),
                  ),
                  trailing: IconButton(
                    onPressed: () => irInclusionThresholdKey.currentState?.ensureTooltipVisible(),
                    icon: const Icon(Icons.info),
                  ),
                ),
                Slider(
                  value: settings.irInclusionThreshold.toDouble(),
                  onChanged: (value) => onSettingsChange(settings.copyWith(irInclusionThreshold: value.round())),
                  min: 0,
                  max: 1024,
                  label: settings.irInclusionThreshold.toString(),
                  divisions: 1024,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
