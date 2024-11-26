import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/editor/painters/ir_read_painter.dart';
import 'package:path_pilot/editor/painters/ir_read_timeline_painter.dart';
import 'package:path_pilot/editor/painters/line_painter.dart';
import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:path_pilot/editor/painters/timeline_painter.dart';
import 'package:path_pilot/helper/file_manager.dart';
import 'package:path_pilot/robi_api/ir_read_api.dart';
import 'package:path_pilot/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import 'obstacles/obstacle.dart';

class InstructionsVisualizer extends Visualizer {
  const InstructionsVisualizer({
    super.key,
    required super.zoom,
    required super.offset,
    required super.robiConfig,
    required super.lockToRobi,
    required super.robiState,
    required super.totalTime,
    required super.highlightedInstruction,
    required SimulationResult simulationResult,
    required super.time,
    required super.onZoomChanged,
    required super.onTimeChanged,
    required super.play,
    required super.onTogglePlay,
    required super.obstacles,
    super.enableTimeInput,
  }) : super(
          simulationResult: simulationResult,
          robiStateType: RobiStateType.innerOuter,
        );
}

class IrVisualizer extends Visualizer {
  const IrVisualizer({
    super.key,
    required super.zoom,
    required super.offset,
    required super.robiConfig,
    required super.lockToRobi,
    required super.robiState,
    required super.totalTime,
    required IrCalculatorResult irCalculatorResult,
    required super.irPathApproximation,
    required IrReadPainterSettings irReadPainterSettings,
    required super.currentMeasurement,
    required super.time,
    super.enableTimeInput = true,
    required super.onZoomChanged,
    required super.onTimeChanged,
    required super.play,
    required super.onTogglePlay,
    required super.obstacles,
    required super.measurementTimeDelta,
  }) : super(
          irCalculatorResultAndSettings: (irCalculatorResult, irReadPainterSettings),
          robiStateType: RobiStateType.leftRight,
        );
}

class Visualizer extends StatelessWidget {
  final double totalTime;
  final RobiConfig robiConfig;
  final bool enableTimeInput;
  final RobiStateType robiStateType;
  final RobiState robiState;
  final List<Obstacle>? obstacles;

  // For InstructionsVisualizer
  final SimulationResult? simulationResult;
  final InstructionResult? highlightedInstruction;

  // For IrVisualizer
  final (IrCalculatorResult, IrReadPainterSettings)? irCalculatorResultAndSettings;
  final List<Vector2>? irPathApproximation;
  final Measurement? currentMeasurement;
  final double? measurementTimeDelta;

  final double zoom;
  final void Function(double newZoom, Offset newOffset, bool lockToRobi) onZoomChanged;

  final Offset offset;

  final bool lockToRobi;

  final double time;
  final void Function(double newTime, Offset newOffset) onTimeChanged;

  final bool play;
  final void Function(bool play) onTogglePlay;

  static const double minZoom = 100;
  static const double maxZoom = 1000;
  static final double log2 = log(2);

  static final double minScale = log(minZoom + 1) / log2;
  static final double maxScale = log(maxZoom + 1) / log2;

  const Visualizer({
    super.key,
    required this.zoom,
    required this.offset,
    required this.robiConfig,
    required this.lockToRobi,
    required this.totalTime,
    required this.robiStateType,
    required this.robiState,
    required this.time,
    required this.onZoomChanged,
    required this.onTimeChanged,
    required this.play,
    required this.onTogglePlay,
    required this.obstacles,
    this.enableTimeInput = true,
    this.simulationResult,
    this.irCalculatorResultAndSettings,
    this.highlightedInstruction,
    this.irPathApproximation,
    this.currentMeasurement,
    this.measurementTimeDelta,
  });

  static double startZoom = (minZoom + maxZoom) / 2;
  static Offset startOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final totalTimeString = printDuration(Duration(milliseconds: (totalTime * 1000).toInt()), SettingsStorage.showMilliseconds);
    final timeString = printDuration(Duration(milliseconds: (time * 1000).toInt()), SettingsStorage.showMilliseconds);

    return Stack(
      children: [
        Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            final oldScale = log(zoom + 1) / log2;
            final newScale = (oldScale - event.scrollDelta.dy / 250).clamp(minScale, maxScale);
            final newZoom = (pow(2, newScale) - 1).toDouble();
            final scaleDelta = log(newZoom + 1) / log2 - oldScale;
            final newOffset = offset * pow(2, scaleDelta).toDouble();
            onZoomChanged(newZoom, newOffset, lockToRobi);
          },
          child: GestureDetector(
            onScaleStart: (details) {
              startZoom = zoom;
              startOffset = details.localFocalPoint - offset;
            },
            onScaleUpdate: (details) {
              if (details.pointerCount > 1) {
                final newZoom = (startZoom * details.scale).clamp(minZoom, maxZoom);
                final scaleDelta = (log(newZoom + 1) - log(zoom + 1)) / log2;
                final newOffset = offset * pow(2, scaleDelta).toDouble();
                onZoomChanged(newZoom, newOffset, lockToRobi);
              } else {
                onZoomChanged(zoom, details.localFocalPoint - startOffset, false);
              }
            },
            child: RepaintBoundary(
              child: CustomPaint(
                painter: LinePainter(
                  robiStateType: robiStateType,
                  robiState: robiState,
                  scale: zoom,
                  robiConfig: robiConfig,
                  simulationResult: simulationResult,
                  highlightedInstruction: highlightedInstruction,
                  irCalculatorResultAndSettings: irCalculatorResultAndSettings,
                  irPathApproximation: irPathApproximation,
                  offset: offset,
                  obstacles: obstacles,
                  currentMeasurement: currentMeasurement,
                  showDeveloperInfo: SettingsStorage.developerMode,
                ),
                child: Container(),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface.withOpacity(0),
                  Theme.of(context).colorScheme.surface,
                ],
                stops: const [0, 1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: timeLinePainter(),
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          thumbShape: SliderComponentShape.noThumb,
                          trackHeight: 4,
                          overlayColor: Theme.of(context).colorScheme.primary,
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                        ),
                        child: Slider(
                          value: time,
                          onChanged: enableTimeInput ? (value) => onTimeChanged(value, offset) : null,
                          max: totalTime,
                          min: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => onTogglePlay(!play),
                            icon: Icon(play ? Icons.pause : Icons.play_arrow),
                            iconSize: 32,
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () => onZoomChanged(zoom, offset, !lockToRobi),
                            icon: Icon(lockToRobi ? Icons.lock : Icons.lock_open),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () => onZoomChanged(zoom, Offset.zero, false),
                            icon: const Icon(Icons.center_focus_strong),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () => exportAsImageDialog(context),
                            icon: const Icon(Icons.image),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text("$timeString / $totalTimeString"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void exportAsImageDialog(BuildContext context) {
    bool showGrid = true,
        showObstacles = true,
        showRobi = true,
        showIrMeasurementInfo = true,
        showLengthScale = false,
        showRobiInfo = false,
        showVelocityScale = false,
        showInstructions = true,
        showIrReadings = true,
        showIrPathApproximation = true;
    final repaintKey = GlobalKey();
    const int maxImageResolution = 20000;

    int resolution = 500;

    double startZoom = this.zoom;
    Offset startOffset = this.offset;

    Offset offset = startOffset;
    double zoom = startZoom;

    bool isConvertingToImage = false;
    bool previewOpen = false;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Scaffold(
            appBar: AppBar(title: const Text("Export as image")),
            body: Stack(
              fit: StackFit.expand,
              children: [
                ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    CheckboxListTile(
                      title: const Text("Show grid"),
                      value: showGrid,
                      onChanged: (value) => setState(() => showGrid = value!),
                    ),
                    if (obstacles != null && obstacles!.isNotEmpty)
                      CheckboxListTile(
                        title: const Text("Show obstacles"),
                        value: showObstacles,
                        onChanged: (value) => setState(() => showObstacles = value!),
                      ),
                    CheckboxListTile(
                      title: const Text("Show Robi"),
                      value: showRobi,
                      onChanged: (value) => setState(() => showRobi = value!),
                    ),
                    CheckboxListTile(
                      title: const Text("Show Robi State Info"),
                      value: showRobiInfo,
                      onChanged: (value) => setState(() => showRobiInfo = value!),
                    ),
                    CheckboxListTile(
                      title: const Text("Show Scale"),
                      value: showLengthScale,
                      onChanged: (value) => setState(() => showLengthScale = value!),
                    ),
                    CheckboxListTile(
                      title: const Text("Show Velocity Scale"),
                      value: showVelocityScale,
                      onChanged: (value) => setState(() => showVelocityScale = value!),
                    ),
                    if (irCalculatorResultAndSettings != null)
                      CheckboxListTile(
                        title: const Text("Show IR Measurement Info"),
                        value: showIrMeasurementInfo,
                        onChanged: (value) => setState(() => showIrMeasurementInfo = value!),
                      ),
                    if (irCalculatorResultAndSettings != null)
                      CheckboxListTile(
                        title: const Text("Show IR Path Approximation"),
                        value: showIrPathApproximation,
                        onChanged: (value) => setState(() => showIrPathApproximation = value!),
                      ),
                    if (irCalculatorResultAndSettings != null)
                      CheckboxListTile(
                        title: const Text("Show IR Readings"),
                        value: showIrReadings,
                        onChanged: (value) => setState(() => showIrReadings = value!),
                      ),
                    if (simulationResult != null && simulationResult!.instructionResults.isNotEmpty)
                      CheckboxListTile(
                        title: const Text("Show Instructions"),
                        value: showInstructions,
                        onChanged: (value) => setState(() => showInstructions = value!),
                      ),
                    const Divider(),
                    Row(
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
                    const SizedBox(height: 600),
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Adjust zoom and position", textAlign: TextAlign.center),
                                  IconButton(
                                    onPressed: () => setState(() => previewOpen = false),
                                    icon: const Icon(Icons.close),
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
                                          painter: LinePainter(
                                            scale: zoom,
                                            robiConfig: robiConfig,
                                            simulationResult: showInstructions ? simulationResult : null,
                                            highlightedInstruction: null,
                                            irCalculatorResultAndSettings: showIrReadings ? irCalculatorResultAndSettings : null,
                                            irPathApproximation: showIrPathApproximation ? irPathApproximation : null,
                                            offset: offset,
                                            robiState: robiState,
                                            robiStateType: robiStateType,
                                            obstacles: showObstacles ? obstacles : null,
                                            currentMeasurement: currentMeasurement,
                                            showGrid: showGrid,
                                            showIrMeasurementInfo: showIrMeasurementInfo,
                                            showLengthScale: showLengthScale,
                                            showRobiStateInfo: showRobiInfo,
                                            showVelocityScale: showVelocityScale,
                                            showRobi: showRobi,
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
                                      zoom = (maxZoom + minZoom) / 2;
                                      offset = Offset.zero;
                                    }),
                                    icon: const Icon(Icons.center_focus_strong),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.file_upload_outlined),
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
                                            } catch (e) {
                                              setState(() => isConvertingToImage = false);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to convert image: $e")));
                                              }
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
            floatingActionButton: previewOpen
                ? null
                : FloatingActionButton(
                    onPressed: () => setState(() => previewOpen = true),
                    child: const Icon(Icons.image),
                  ),
          );
        });
      },
    ));
  }

  Widget timeLinePainter() {
    const maxInstructions = 10000;
    const timelineSize = Size.fromHeight(15);

    if (simulationResult != null && simulationResult!.instructionResults.length <= maxInstructions) {
      return RepaintBoundary(
        key: ValueKey(simulationResult.hashCode + highlightedInstruction.hashCode),
        child: CustomPaint(
          size: timelineSize,
          painter: TimelinePainter(
            simResult: simulationResult!,
            highlightedInstruction: highlightedInstruction,
          ),
        ),
      );
    } else if (irCalculatorResultAndSettings != null && measurementTimeDelta != null && irCalculatorResultAndSettings!.$1.length <= maxInstructions) {
      return RepaintBoundary(
        key: ValueKey(irCalculatorResultAndSettings!.$1.hashCode),
        child: CustomPaint(
          size: timelineSize,
          painter: IrReadTimelinePainter(
            totalTime: totalTime,
            measurementsTimeDelta: measurementTimeDelta!,
          ),
        ),
      );
    }
    return const SizedBox();
  }
}

String printDuration(Duration duration, bool showMilliseconds) {
  String twoDigits(int n) => n.toString().padLeft(2, "0").substring(0, 2);
  String twoDigitMinutes = duration.inMinutes.remainder(60).abs().toString();
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60).abs());
  if (!showMilliseconds) return "$twoDigitMinutes:$twoDigitSeconds";
  String twoDigitMilliseconds = twoDigits(duration.inMilliseconds.remainder(1000).abs());
  return "$twoDigitMinutes:$twoDigitSeconds:$twoDigitMilliseconds";
}
