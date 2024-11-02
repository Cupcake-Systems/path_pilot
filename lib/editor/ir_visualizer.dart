import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/painters/ir_read_painter.dart';
import 'package:robi_line_drawer/editor/painters/robi_painter.dart';
import 'package:robi_line_drawer/editor/visualizer.dart';
import 'package:vector_math/vector_math.dart';

import '../robi_api/ir_read_api.dart';
import '../robi_api/robi_utils.dart';
import 'ir_line_approximation/approximation_settings_widget.dart';
import 'ir_line_approximation/ir_reading_info.dart';

class IrVisualizerWidget extends StatefulWidget {
  final IrReadResult irReadResult;
  final RobiConfig robiConfig;
  final void Function(List<Vector2> pathApproximation) onPathCreationClick;
  final double time;
  final bool enableTimeInput;

  const IrVisualizerWidget({
    super.key,
    required this.robiConfig,
    required this.onPathCreationClick,
    required this.irReadResult,
    this.time = 0,
    this.enableTimeInput = true,
  });

  @override
  State<IrVisualizerWidget> createState() => _IrVisualizerWidgetState();
}

class _IrVisualizerWidgetState extends State<IrVisualizerWidget> {
  double ramerDouglasPeuckerTolerance = 0.5;
  IrReadPainterSettings irReadPainterSettings = defaultIrReadPainterSettings();
  int irInclusionThreshold = 100;

  List<Vector2>? irPathApproximation;

  @override
  Widget build(BuildContext context) {
    final irCalculatorResult = IrCalculator.calculate(widget.irReadResult, widget.robiConfig);
    approximateIrPath(irCalculatorResult);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 3 / 2,
          child: IrVisualizer(
            timeOffset: widget.time,
            enableTimeInput: widget.enableTimeInput,
            scale: 10,
            offset: Offset.zero,
            transformChanged: (zoom, offset, lockToRobi) {},
            robiConfig: widget.robiConfig,
            lockToRobi: false,
            getStateAtTime: (t) {
              final res = widget.irReadResult;

              if (res.measurements.isEmpty) {
                return RobiState.zero;
              }

              if (res.measurements.length == 1) {
                return irCalculatorResult.robiStates.first;
              }

              for (int i = 0; i < res.measurements.length - 1; ++i) {
                if (t <= res.resolution * (i + 1)) {
                  return irCalculatorResult.robiStates[i].interpolate(irCalculatorResult.robiStates[i + 1], (t - (res.resolution * (i))) / res.resolution);
                }
              }

              return irCalculatorResult.robiStates.last;
            },
            totalTime: widget.irReadResult.totalTime,
            irCalculatorResult: irCalculatorResult,
            irPathApproximation: irPathApproximation,
            irReadPainterSettings: irReadPainterSettings,
          ),
        ),
        const Divider(height: 0),
        IrPathApproximationSettingsWidget(
          onPathCreation: irPathApproximation == null ? null : () => widget.onPathCreationClick(irPathApproximation!),
          onSettingsChange: (
            settings,
            irInclusionThreshold,
            ramerDouglasPeuckerTolerance,
          ) {
            setState(() {
              irReadPainterSettings = settings;
              this.irInclusionThreshold = irInclusionThreshold;
              this.ramerDouglasPeuckerTolerance = ramerDouglasPeuckerTolerance;
              approximateIrPath(irCalculatorResult);
            });
          },
        ),
        IrReadingInfoWidget(
          selectedRobiConfig: widget.robiConfig,
          irReadResult: widget.irReadResult,
          irCalculatorResult: irCalculatorResult,
        ),
      ],
    );
  }

  void approximateIrPath(IrCalculatorResult irCalculatorResult) {
    irPathApproximation = IrCalculator.pathApproximation(
      irCalculatorResult,
      irInclusionThreshold,
      ramerDouglasPeuckerTolerance,
    );
  }
}
