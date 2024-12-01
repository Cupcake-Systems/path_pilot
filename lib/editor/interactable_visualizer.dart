import 'package:flutter/material.dart';
import 'package:path_pilot/app_storage.dart';
import 'package:path_pilot/editor/painters/ir_read_painter.dart';
import 'package:path_pilot/editor/painters/line_painter_settings/line_painter_visibility_settings.dart';
import 'package:path_pilot/editor/visualizer.dart';
import 'package:path_pilot/robi_api/ir_read_api.dart';
import 'package:vector_math/vector_math.dart';

import '../robi_api/robi_utils.dart';
import 'obstacles/obstacle.dart';

const double frameTimeMultiplier = 2 / 3; // tests showed that the visualizer is not producing the desired fps, so we need to adjust the time to get the desired fps

class InteractableIrVisualizer extends StatefulWidget {
  final bool enableTimeInput;
  final RobiConfig robiConfig;
  final IrCalculatorResult irCalculatorResult;
  final List<Vector2>? irPathApproximation;
  final IrReadPainterSettings irReadPainterSettings;
  final IrReadResult irReadResult;
  final double totalTime;
  final List<Obstacle>? obstacles;
  final void Function(LinePainterVisibilitySettings newSettings) onVisibilitySettingsChange;

  final void Function(double newTime)? onTimeChanged;

  const InteractableIrVisualizer({
    super.key = const ValueKey('InteractableIrVisualizer'),
    required this.enableTimeInput,
    required this.robiConfig,
    required this.irCalculatorResult,
    required this.irPathApproximation,
    required this.irReadPainterSettings,
    required this.totalTime,
    required this.irReadResult,
    required this.obstacles,
    required this.onVisibilitySettingsChange,
    this.onTimeChanged,
  });

  @override
  State<InteractableIrVisualizer> createState() => _InteractableIrVisualizerState();
}

class _InteractableIrVisualizerState extends State<InteractableIrVisualizer> {
  double zoom = (Visualizer.maxZoom + Visualizer.minZoom) / 2;
  Offset offset = Offset.zero;
  Offset dragStartOffset = Offset.zero;
  bool lockToRobi = false;
  bool updateRobi = false;
  double timeOffset = 0;
  double speedMultiplier = 1;

  LinePainterVisibilitySettings visibilitySettings = LinePainterVisibilitySettings.of([
    ...LinePainterVisibilitySettings.universalSettings,
    ...LinePainterVisibilitySettings.onlyIrSettings,
  ])
    ..set(LinePainterVisibility.irPathApproximation, false);

  final deltaCounter = Stopwatch();

  @override
  void dispose() {
    deltaCounter.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double timeSnapshot = timeOffset + deltaCounter.elapsedMilliseconds / 1000 * speedMultiplier;

    if (timeSnapshot >= widget.totalTime) {
      timeSnapshot = widget.totalTime;
      pause();
    }

    if (SettingsStorage.limitFps) {
      final updateDelay = frameTimeMultiplier / SettingsStorage.visualizerFps;
      Future.delayed(Duration(milliseconds: (updateDelay * 1000).toInt()), () {
        if (!updateRobi) return;
        updateTime(timeSnapshot + updateDelay);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!updateRobi) return;
        updateTime(timeSnapshot);
      });
    }

    final robiState = widget.irCalculatorResult.getStateAtTime(widget.irReadResult, timeSnapshot);
    if (lockToRobi) {
      offset = Offset(-robiState.position.x, robiState.position.y) * zoom;
    }

    final currentMeasurement = widget.irReadResult.getMeasurementAtTime(timeSnapshot);

    return IrVisualizer(
      visibilitySettings: visibilitySettings,
      zoom: zoom,
      offset: offset,
      robiConfig: widget.robiConfig,
      lockToRobi: lockToRobi,
      totalTime: widget.totalTime,
      robiState: robiState,
      time: timeSnapshot,
      obstacles: widget.obstacles,
      currentMeasurement: currentMeasurement,
      onZoomChanged: (newZoom, newOffset, newLockToRobi) => setState(() {
        offset = newOffset;
        zoom = newZoom;
        lockToRobi = newLockToRobi;
      }),
      onVisibilitySettingsChange: (settings) {
        setState(() => visibilitySettings = settings);
        widget.onVisibilitySettingsChange(settings);
      },
      measurementTimeDelta: widget.irReadResult.resolution,
      onTimeChanged: (newTime, newOffset) => setState(() {
        timeOffset = newTime;
        pause();
        deltaCounter.reset();
        updateTime(newTime);
      }),
      irCalculatorResult: widget.irCalculatorResult,
      irPathApproximation: widget.irPathApproximation,
      irReadPainterSettings: widget.irReadPainterSettings,
      play: updateRobi,
      onTogglePlay: (p) {
        if (timeSnapshot >= widget.totalTime) {
          timeOffset = 0;
          deltaCounter.reset();
        }

        if (p) {
          setState(() => play());
        } else {
          setState(() => pause());
        }
      },
      speedMultiplier: speedMultiplier,
      onSpeedMultiplierChanged: (newSpeed) {
        timeOffset = timeSnapshot;
        deltaCounter.reset();
        setState(() => speedMultiplier = newSpeed);
      },
    );
  }

  void play() {
    deltaCounter.start();
    updateRobi = true;
  }

  void pause() {
    deltaCounter.stop();
    updateRobi = false;
  }

  void updateTime(double time) {
    if (widget.onTimeChanged == null) {
      setState(() {});
    } else {
      widget.onTimeChanged!(time);
    }
  }
}

class InteractableInstructionsVisualizer extends StatefulWidget {
  final RobiConfig robiConfig;
  final double totalTime;
  final InstructionResult? highlightedInstruction;
  final SimulationResult simulationResult;
  final List<Obstacle>? obstacles;

  final void Function(double newTime)? onTimeChanged;

  const InteractableInstructionsVisualizer({
    super.key = const ValueKey('InteractableInstructionsVisualizer'),
    required this.robiConfig,
    required this.totalTime,
    required this.simulationResult,
    required this.obstacles,
    this.highlightedInstruction,
    this.onTimeChanged,
  });

  @override
  State<InteractableInstructionsVisualizer> createState() => _InteractableInstructionsVisualizerState();
}

class _InteractableInstructionsVisualizerState extends State<InteractableInstructionsVisualizer> {
  double zoom = (Visualizer.maxZoom + Visualizer.minZoom) / 2;
  Offset offset = Offset.zero;
  Offset dragStartOffset = Offset.zero;
  bool lockToRobi = false;
  bool updateRobi = false;
  double timeOffset = 0;
  double speedMultiplier = 1;

  final deltaCounter = Stopwatch();
  LinePainterVisibilitySettings visibilitySettings = LinePainterVisibilitySettings.of([
    ...LinePainterVisibilitySettings.universalSettings,
    ...LinePainterVisibilitySettings.onlySimulationSettings,
  ]);

  @override
  Widget build(BuildContext context) {
    double timeSnapshot = timeOffset + deltaCounter.elapsedMilliseconds / 1000 * speedMultiplier;

    if (timeSnapshot >= widget.totalTime) {
      timeSnapshot = widget.totalTime;
      pause();
    }

    if (SettingsStorage.limitFps) {
      final updateDelay = frameTimeMultiplier / SettingsStorage.visualizerFps;
      Future.delayed(Duration(milliseconds: (updateDelay * 1000).toInt()), () {
        if (!updateRobi) return;
        updateTime(timeSnapshot + updateDelay);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!updateRobi) return;
        updateTime(timeSnapshot);
      });
    }

    final robiState = widget.simulationResult.getStateAtTime(timeSnapshot);
    if (lockToRobi) {
      offset = Offset(-robiState.position.x, robiState.position.y) * zoom;
    }

    return InstructionsVisualizer(
      visibilitySettings: visibilitySettings,
      obstacles: widget.obstacles,
      zoom: zoom,
      offset: offset,
      robiConfig: widget.robiConfig,
      lockToRobi: lockToRobi,
      robiState: robiState,
      totalTime: widget.totalTime,
      highlightedInstruction: widget.highlightedInstruction,
      simulationResult: widget.simulationResult,
      onVisibilitySettingsChange: (settings) => setState(() {
        visibilitySettings = settings;
      }),
      time: timeSnapshot,
      onZoomChanged: (newZoom, newOffset, newLockToRobi) => setState(() {
        offset = newOffset;
        zoom = newZoom;
        lockToRobi = newLockToRobi;
      }),
      onTimeChanged: (newTime, newOffset) {
        timeOffset = newTime;
        pause();
        deltaCounter.reset();
        updateTime(newTime);
      },
      play: updateRobi,
      onTogglePlay: (p) {
        if (timeSnapshot >= widget.totalTime) {
          timeOffset = 0;
          deltaCounter.reset();
        }

        if (p) {
          setState(() => play());
        } else {
          setState(() => pause());
        }
      },
      speedMultiplier: speedMultiplier,
      onSpeedMultiplierChanged: (newSpeed) => setState(() => speedMultiplier = newSpeed),
    );
  }

  void play() {
    deltaCounter.start();
    updateRobi = true;
  }

  void pause() {
    deltaCounter.stop();
    updateRobi = false;
  }

  void updateTime(double time) {
    if (time > widget.totalTime) {
      time = widget.totalTime;
    }

    widget.onTimeChanged?.call(time);
    setState(() {});
  }
}
