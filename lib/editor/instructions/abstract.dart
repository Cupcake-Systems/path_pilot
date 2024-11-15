import 'package:flutter/material.dart';
import 'package:path_pilot/editor/editor.dart';
import 'package:path_pilot/editor/instructions/instruction_details.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../robi_api/robi_utils.dart';

abstract class AbstractEditor extends StatelessWidget {
  final SimulationResult simulationResult;
  final int instructionIndex;
  final MissionInstruction instruction;
  final RobiConfig robiConfig;
  final double progress;

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
    String? warning,
    this.entered,
    this.exited,
    required this.progress,
  }) : _warning = warning {
    instructionResult = simulationResult.instructionResults[instructionIndex];
    isLastInstruction = instructionIndex == simulationResult.instructionResults.length - 1;
  }

  String? _generateWarning() {
    if (_warning != null) return _warning;
    if (isLastInstruction && instructionResult.highestFinalVelocity.abs() > 0.00001) {
      return "Robi will not stop at the end";
    }
    if ((instructionResult.highestMaxVelocity - instruction.targetVelocity).abs() > 0.000001) {
      return "Robi will only reach ${roundToDigits(instructionResult.highestMaxVelocity * 100, 2)}cm/s";
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
  final double progress;

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
    required this.progress,
  });

  @override
  State<RemovableWarningCard> createState() => _RemovableWarningCardState();
}

String vecToString(Vector2 vec, int decimalPlaces) => "(${vec.x.toStringAsFixed(decimalPlaces)}, ${vec.y.toStringAsFixed(decimalPlaces)})";

class _RemovableWarningCardState extends State<RemovableWarningCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) => widget.entered?.call(widget.instructionResult),
      onExit: (event) => widget.exited?.call(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: LinearProgressIndicator(
                value: widget.progress,
                minHeight: 2,
              ),
            ),
            ExpansionTile(
              tilePadding: const EdgeInsets.only(right: 20),
              onExpansionChanged: (value) => setState(() => isExpanded = value),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              childrenPadding: const EdgeInsets.all(8),
              title: widget.header,
              trailing: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: widget.removed,
                  icon: const Icon(Icons.delete),
                ),
              ),
              leading: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              subtitle: widget.warningMessage == null
                  ? null
                  : Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.yellow.withAlpha(50)),
                      child: Row(
                        children: [
                          const Icon(Icons.warning),
                          const SizedBox(width: 10),
                          Text(widget.warningMessage ?? ""),
                        ],
                      ),
                    ),
              children: isExpanded
                  ? [
                      Padding(
                        padding: const EdgeInsets.only(right: 26),
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
                                  value: widget.instruction.acceleration,
                                  onChanged: (value) {
                                    widget.instruction.acceleration = roundToDigits(value, 3);
                                    widget.change(widget.instruction);
                                  },
                                ),
                                Text("${roundToDigits(widget.instruction.acceleration * 100, 2)}cm/s²"),
                              ],
                            ),
                            TableRow(
                              children: [
                                const Text("Target Velocity"),
                                Slider(
                                  value: widget.instruction.targetVelocity,
                                  onChanged: (value) {
                                    widget.instruction.targetVelocity = roundToDigits(value, 3);
                                    widget.change(widget.instruction);
                                  },
                                  min: 0.001,
                                ),
                                Text("${roundToDigits(widget.instruction.targetVelocity * 100, 2)}cm/s"),
                              ],
                            ),
                            ...widget.children,
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      InstructionDetailsWidget(
                        instructionResult: widget.instructionResult,
                        robiConfig: widget.robiConfig,
                        instructionProgress: widget.progress == 0 || widget.progress >= 1? null : widget.progress,
                      ),
                    ]
                  : const [],
            ),
          ],
        ),
      ),
    );
  }
}
