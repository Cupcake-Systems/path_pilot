import 'package:flutter/material.dart';

import '../painters/ir_read_painter.dart';

IrReadPainterSettings defaultIrReadPainterSettings() => IrReadPainterSettings(
      irReadingsThreshold: 1024,
      showCalculatedPath: true,
      showTracks: false,
    );

class IrPathApproximationSettingsWidget extends StatefulWidget {
  final void Function(
    IrReadPainterSettings settings,
    int irInclusionThreshold,
    double ramerDouglasPeuckerTolerance,
  ) onSettingsChange;
  final void Function()? onPathCreation;

  const IrPathApproximationSettingsWidget({
    super.key,
    required this.onSettingsChange,
    required this.onPathCreation,
  });

  @override
  State<IrPathApproximationSettingsWidget> createState() => _IrPathApproximationSettingsWidgetState();
}

class _IrPathApproximationSettingsWidgetState extends State<IrPathApproximationSettingsWidget> with AutomaticKeepAliveClientMixin {
  IrReadPainterSettings settings = defaultIrReadPainterSettings();
  int irInclusionThreshold = 100;
  double ramerDouglasPeuckerTolerance = 0.5;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Visibility",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      children: [
                        const Text("Show wheel track"),
                        Checkbox(
                          value: settings.showTracks,
                          onChanged: (value) {
                            setState(() => settings.showTracks = value!);
                            settingsChange();
                          },
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Text("Show only IR readings < ${settings.irReadingsThreshold}"),
                        Slider(
                          value: settings.irReadingsThreshold.toDouble(),
                          onChanged: (value) {
                            setState(() {
                              settings.irReadingsThreshold = value.round();
                            });
                            settingsChange();
                          },
                          max: 1024,
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Text("Show calculated path"),
                        Checkbox(
                          value: settings.showCalculatedPath,
                          onChanged: (value) => setState(() {
                            settings.showCalculatedPath = value!;
                            settingsChange();
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Path Approximation",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      children: [
                        const Text("Ramer Douglas Peucker tolerance"),
                        Slider(
                          value: ramerDouglasPeuckerTolerance,
                          onChanged: (value) {
                            setState(() {
                              ramerDouglasPeuckerTolerance = value;
                            });
                            settingsChange();
                          },
                          max: 5,
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Text("IR inclusion threshold: $irInclusionThreshold"),
                        Slider(
                          value: irInclusionThreshold.toDouble(),
                          onChanged: (value) {
                            setState(() {
                              irInclusionThreshold = value.round();
                            });
                            settingsChange();
                          },
                          max: 1024,
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        const Text("Convert to Path"),
                        OutlinedButton(
                          onPressed: widget.onPathCreation,
                          child: const Text("To Path"),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void settingsChange() => widget.onSettingsChange(settings, irInclusionThreshold, ramerDouglasPeuckerTolerance);

  @override
  bool get wantKeepAlive => true;
}
