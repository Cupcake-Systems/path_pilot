import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_pilot/editor/editor.dart';
import 'package:path_pilot/editor/instructions/instruction_details.dart';
import 'package:path_pilot/editor/painters/robi_painter.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../robi_api/robi_utils.dart';

abstract class AbstractEditor extends StatelessWidget {
  final SimulationResult simulationResult;
  final int instructionIndex;
  final MissionInstruction instruction;
  final RobiConfig robiConfig;
  final TimeChangeNotifier timeChangeNotifier;
  final MissionInstruction? nextInstruction;

  late final InstructionResult instructionResult;
  late final bool isLastInstruction;

  final Function(MissionInstruction newInstruction) change;
  final Function() removed;
  final Function(InstructionResult instructionResult)? entered;
  final Function()? exited;

  late final String? warningMessage = _generateWarning();
  final String? _warning;

  AbstractEditor({
    super.key,
    required this.simulationResult,
    required this.instructionIndex,
    required this.change,
    required this.removed,
    required this.instruction,
    required this.robiConfig,
    required this.nextInstruction,
    String? warning,
    this.entered,
    this.exited,
    required this.timeChangeNotifier,
  }) : _warning = warning {
    instructionResult = simulationResult.instructionResults[instructionIndex];
    isLastInstruction = instructionIndex == simulationResult.instructionResults.length - 1;
  }

  String? _generateWarning() {
    if (_warning != null) return _warning;

    if (isLastInstruction && instructionResult.highestFinalVelocity.abs() > floatTolerance) {
      return "Robi will not stop at the end";
    }
    if ((instructionResult.highestMaxVelocity - instruction.targetVelocity).abs() > floatTolerance) {
      return "Robi will only reach ${roundToDigits(instructionResult.highestMaxVelocity * 100, 2)}cm/s";
    }
    if (instructionResult.highestMaxVelocity > robiConfig.maxVelocity) {
      return "Robi will exceed the maximum velocity";
    }
    if (instructionResult.maxAcceleration > robiConfig.maxAcceleration) {
      return "Robi will exceed the maximum acceleration";
    }
    if (nextInstruction != null && instructionResult.highestFinalVelocity > nextInstruction!.targetVelocity + floatTolerance) {
      return "Robi's final velocity must be <= ${roundToDigits(nextInstruction!.targetVelocity * 100, 2)}cm/s";
    }
    return null;
  }
}

class RemovableWarningCard extends StatefulWidget {
  final Function() removed;
  final Function(InstructionResult instructionResult)? entered;
  final Function()? exited;
  final Function(MissionInstruction instruction) change;
  final RobiConfig robiConfig;
  final TimeChangeNotifier timeChangeNotifier;

  final Widget header;
  final List<TableRow> children;

  final InstructionResult instructionResult;
  final MissionInstruction instruction;

  final String? warningMessage;

  const RemovableWarningCard({
    super.key,
    required this.children,
    required this.instructionResult,
    required this.instruction,
    required this.removed,
    this.entered,
    this.exited,
    required this.change,
    this.warningMessage,
    required this.header,
    required this.robiConfig,
    required this.timeChangeNotifier,
  });

  @override
  State<RemovableWarningCard> createState() => _RemovableWarningCardState();
}

String vecToString(Vector2 vec, int decimalPlaces) => "(${vec.x.toStringAsFixed(decimalPlaces)}, ${vec.y.toStringAsFixed(decimalPlaces)})";

class _RemovableWarningCardState extends State<RemovableWarningCard> {
  bool isExpanded = false;

  double get progress {
    if (widget.instructionResult.totalTime == 0) return 0;
    return (widget.timeChangeNotifier.time - widget.instructionResult.timeStamp) / widget.instructionResult.totalTime;
  }

  @override
  Widget build(BuildContext context) {
    final accelSliderMax = widget.robiConfig.maxAcceleration;
    final velSliderMax = widget.robiConfig.maxVelocity;

    final accelSliderValue = widget.instruction.acceleration > accelSliderMax ? accelSliderMax : widget.instruction.acceleration;
    final velSliderValue = widget.instruction.targetVelocity > velSliderMax ? velSliderMax : widget.instruction.targetVelocity;

    return MouseRegion(
      onEnter: (event) => widget.entered?.call(widget.instructionResult),
      onExit: (event) => widget.exited?.call(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ListenableBuilder(
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                  );
                },
                listenable: widget.timeChangeNotifier,
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.only(left: 8, right: Platform.isAndroid ? 8 : 30),
              onExpansionChanged: (value) => setState(() => isExpanded = value),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              visualDensity: VisualDensity.compact,
              childrenPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: widget.header,
              trailing: IconButton(
                onPressed: widget.removed,
                icon: const Icon(Icons.delete),
              ),
              subtitle: widget.warningMessage == null
                  ? null
                  : Card.filled(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: Colors.yellow.withAlpha(50),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          children: [
                            const Icon(Icons.warning, size: 18),
                            const SizedBox(width: 10),
                            Text(widget.warningMessage ?? "", overflow: TextOverflow.fade, maxLines: 2),
                          ],
                        ),
                      ),
                    ),
              children: isExpanded
                  ? [
                      Padding(
                        padding: Platform.isAndroid ? const EdgeInsets.only(left: 16, bottom: 10, right: 16, top: 16) : const EdgeInsets.only(right: 30, left: 16, top: 16, bottom: 10),
                        child: Table(
                          columnWidths: const {
                            0: IntrinsicColumnWidth(),
                            1: FlexColumnWidth(),
                            2: IntrinsicColumnWidth(),
                          },
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              children: [
                                const Text("Acceleration"),
                                Slider(
                                  value: accelSliderValue,
                                  onChanged: (value) {
                                    widget.instruction.acceleration = roundToDigits(value, 3);
                                    widget.change(widget.instruction);
                                  },
                                  max: accelSliderMax,
                                ),
                                Text("${roundToDigits(widget.instruction.acceleration * 100, 2)}cm/s²"),
                              ],
                            ),
                            TableRow(
                              children: [
                                const Text("Target Velocity"),
                                Slider(
                                  value: velSliderValue,
                                  onChanged: (value) {
                                    widget.instruction.targetVelocity = roundToDigits(value, 3);
                                    widget.change(widget.instruction);
                                  },
                                  min: 0.001,
                                  max: velSliderMax,
                                ),
                                Text("${roundToDigits(widget.instruction.targetVelocity * 100, 2)}cm/s"),
                              ],
                            ),
                            ...widget.children,
                          ],
                        ),
                      ),
                      if (widget.instructionResult.totalTime > 0) ...[
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Padding(
                          padding: Platform.isAndroid ? const EdgeInsets.all(16) : const EdgeInsets.only(left: 16, right: 30, top: 16, bottom: 16),
                          child: InstructionDetailsWidget(
                            instructionResult: widget.instructionResult,
                            robiConfig: widget.robiConfig,
                            timeChangeNotifier: widget.timeChangeNotifier,
                          ),
                        ),
                      ],
                    ]
                  : const [],
            ),
          ],
        ),
      ),
    );
  }
}
