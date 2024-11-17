import 'package:flutter/material.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:path_pilot/editor/painters/ir_read_painter.dart';
import 'package:path_pilot/file_browser.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../robi_api/ir_read_api.dart';
import '../../robi_api/robi_utils.dart';
import '../interactable_visualizer.dart';
import 'approximation_settings_widget.dart';
import 'ir_reading_info.dart';

class IrVisualizerWidget extends StatefulWidget {
  final IrReadResult irReadResult;
  final RobiConfig robiConfig;
  final double time;
  final bool enableTimeInput;
  final SubViewMode subViewMode;

  const IrVisualizerWidget({
    super.key,
    required this.robiConfig,
    required this.irReadResult,
    this.time = 0,
    this.enableTimeInput = true,
    required this.subViewMode,
  });

  @override
  State<IrVisualizerWidget> createState() => _IrVisualizerWidgetState();
}

class _IrVisualizerWidgetState extends State<IrVisualizerWidget> {
  late final IrCalculatorResult irCalculatorResult = IrCalculator.calculate(widget.irReadResult, widget.robiConfig);

  IrReadPainterSettings irReadPainterSettings = defaultIrReadPainterSettings;

  List<Vector2>? irPathApproximation;

  @override
  Widget build(BuildContext context) {
    irPathApproximation = IrCalculator.pathApproximation(
      irCalculatorResult,
      irReadPainterSettings.irInclusionThreshold,
      irReadPainterSettings.ramerDouglasPeuckerTolerance,
    );

    InteractableIrVisualizer? visualizer;
    Widget? editor;

    if (widget.subViewMode == SubViewMode.split || widget.subViewMode == SubViewMode.visualizer) {
      visualizer = InteractableIrVisualizer(
        enableTimeInput: widget.enableTimeInput,
        robiConfig: widget.robiConfig,
        totalTime: widget.irReadResult.totalTime,
        irCalculatorResult: irCalculatorResult,
        irPathApproximation: irPathApproximation,
        irReadPainterSettings: irReadPainterSettings,
        irReadResult: widget.irReadResult,
      );
    }
    if (widget.subViewMode == SubViewMode.split || widget.subViewMode == SubViewMode.editor) {
      editor = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          IrPathApproximationSettingsWidget(
            onSettingsChange: (settings) => setState(() => irReadPainterSettings = settings), settings: irReadPainterSettings,
          ),
          const SizedBox(height: 16),
          IrReadingInfoWidget(
            selectedRobiConfig: widget.robiConfig,
            irReadResult: widget.irReadResult,
            irCalculatorResult: irCalculatorResult,
          ),
        ],
      );
    }

    switch (widget.subViewMode) {
      case SubViewMode.editor:
        return editor!;
      case SubViewMode.visualizer:
        return visualizer!;
      case SubViewMode.split:
        final screenSize = MediaQuery.of(context).size;
        final isPortrait = screenSize.width < screenSize.height;
        return ResizableContainer(
          direction: isPortrait ? Axis.vertical : Axis.horizontal,
          divider: ResizableDivider(thickness: 3, color: Colors.grey[800]),
          children: [
            ResizableChild(child: visualizer!),
            ResizableChild(child: editor!),
          ],
        );
    }
  }
}
