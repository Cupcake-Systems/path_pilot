import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/editor/painters/foreground_painter.dart';
import 'package:path_pilot/editor/painters/line_painter.dart';
import 'package:path_pilot/editor/painters/line_painter_settings/line_painter_visibility_settings.dart';
import 'package:path_pilot/editor/visualizer.dart';
import 'package:path_pilot/helper/dialogs.dart';
import 'package:path_pilot/main.dart';

import '../helper/file_manager.dart';
import '../helper/geometry.dart';

class VisualizerImageExporter extends StatefulWidget {
  final Visualizer viz;

  const VisualizerImageExporter({super.key, required this.viz});

  @override
  State<VisualizerImageExporter> createState() => _VisualizerImageExporterState();
}

class _VisualizerImageExporterState extends State<VisualizerImageExporter> {
  static const int maxImageResolution = 20000;

  final repaintKey = GlobalKey();

  Visualizer get viz => widget.viz;

  late var visibilitySettings = viz.visibilitySettings.copy();
  late Offset startOffset = viz.offset;
  late double startZoom = viz.zoom;
  late Offset offset = startOffset;
  late double zoom = startZoom;

  bool isConvertingToImage = false;
  bool previewOpen = false;
  int resolution = 2048;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.titleSmall!.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer);
    return Scaffold(
      appBar: AppBar(title: const Text("Export as image")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Visualizer", style: headerStyle),
              ),
              for (final v in visibilitySettings.availableUniversalSettings) ...[
                CheckboxListTile(
                  value: visibilitySettings.isVisible(v),
                  title: Text(LinePainterVisibilitySettings.nameOf(v)),
                  onChanged: (value) {
                    setState(() => visibilitySettings.set(v, value == true));
                  },
                ),
              ],
              if (visibilitySettings.availableNonUniversalSettings.isNotEmpty) const Divider(height: 1),
              for (final v in visibilitySettings.availableNonUniversalSettings) ...[
                CheckboxListTile(
                  value: visibilitySettings.isVisible(v),
                  title: Text(LinePainterVisibilitySettings.nameOf(v)),
                  onChanged: (value) {
                    setState(() => visibilitySettings.set(v, value == true));
                  },
                ),
              ],
              Padding(padding: const EdgeInsets.all(16), child: Text("Image", style: headerStyle)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text("Resolution: ", style: TextStyle(fontSize: 16)),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: resolution.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed == null || parsed <= 0) return;
                          setState(() => resolution = parsed.clamp(1, maxImageResolution));
                        },
                      ),
                    ),
                    Text(" x $resolution px", style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              if (previewOpen) const SizedBox(height: 600),
            ],
          ),
          if (previewOpen)
            Align(
              alignment: Alignment.bottomCenter,
              child: Card(
                margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  const Text("Preview", textAlign: TextAlign.center),
                                  Text(
                                    "Resolution: $resolution x $resolution px\nPan and zoom to adjust",
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  )
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                onPressed: () => setState(() => previewOpen = false),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerSignal: (event) {
                            if (event is! PointerScrollEvent) return;
                            final oldScale = log(zoom + 1) / log2;
                            final newScale = (oldScale - event.scrollDelta.dy / 250);
                            setState(() {
                              zoom = (pow(2, newScale) - 1).toDouble();
                              final scaleDelta = log(zoom + 1) / log2 - oldScale;
                              offset = offset * pow(2, scaleDelta).toDouble();
                            });
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onScaleStart: (details) {
                              startZoom = zoom;
                              startOffset = details.localFocalPoint - offset;
                            },
                            onScaleUpdate: (details) {
                              if (details.pointerCount > 1) {
                                setState(() {
                                  final newZoom = (startZoom * details.scale);
                                  final scaleDelta = (log(newZoom + 1) - log(zoom + 1)) / log2;
                                  zoom = newZoom;
                                  offset *= pow(2, scaleDelta).toDouble();
                                });
                              } else {
                                setState(() => offset = details.localFocalPoint - startOffset);
                              }
                            },
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                                child: RepaintBoundary(
                                  key: repaintKey,
                                  child: CustomPaint(
                                    foregroundPainter: ForegroundPainter(
                                      scale: zoom,
                                      showDeveloperInfo: SettingsStorage.developerMode,
                                      visibilitySettings: visibilitySettings,
                                      simulationResult: viz.simulationResult,
                                      irCalculatorResultAndSettings: viz.irCalculatorResultAndSettings,
                                      currentMeasurement: viz.currentMeasurement,
                                      robiState: viz.robiState,
                                      robiStateType: viz.robiStateType,
                                    ),
                                    painter: LinePainter(
                                      scale: zoom,
                                      robiConfig: viz.robiConfig,
                                      simulationResult: viz.simulationResult,
                                      highlightedInstruction: null,
                                      irCalculatorResultAndSettings: viz.irCalculatorResultAndSettings,
                                      irPathApproximation: viz.irPathApproximation,
                                      offset: offset,
                                      robiState: viz.robiState,
                                      obstacles: viz.obstacles,
                                      visibilitySettings: visibilitySettings,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => setState(() {
                                zoom = (Visualizer.maxZoom + Visualizer.minZoom) / 2;
                                offset = Offset.zero;
                              }),
                              icon: const Icon(Icons.center_focus_strong),
                            ),
                            IconButton(
                              icon: isConvertingToImage
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 3),
                                    )
                                  : const Icon(Icons.file_upload_outlined),
                              onPressed: isConvertingToImage
                                  ? null
                                  : () async {
                                      if (isConvertingToImage) return;
                                      setState(() => isConvertingToImage = true);

                                      try {
                                        final size = repaintKey.currentContext!.size!.width;
                                        final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                                        final img = await boundary.toImage(pixelRatio: resolution.clamp(1, maxImageResolution) / size);
                                        final byteData = await img.toByteData(format: ImageByteFormat.png);
                                        setState(() => isConvertingToImage = false);

                                        if (byteData == null || !context.mounted) return;

                                        await pickFileAndWriteWithStatusMessage(
                                          bytes: byteData.buffer.asUint8List(),
                                          context: context,
                                          extension: ".png",
                                        );
                                      } catch (e, s) {
                                        setState(() => isConvertingToImage = false);
                                        logger.errorWithStackTrace("Failed to convert image", e, s);
                                        showSnackBar("Failed to convert image: $e");
                                        return;
                                      }
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: previewOpen || !visibilitySettings.anyVisible()
          ? null
          : FloatingActionButton(
              onPressed: () => setState(() => previewOpen = true),
              child: const Icon(Icons.image),
            ),
    );
  }
}
