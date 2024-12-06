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
  final List<Widget> children;

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
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  widget.header,
                  if (widget.warningMessage != null) ...[
                    SizedBox(
                      height: 38,
                      width: 38,
                      child: IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Warning"),
                              content: Text(widget.warningMessage!),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text("Close"),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.warning, color: Colors.yellow),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: IconButton(
                onPressed: widget.removed,
                icon: const Icon(Icons.delete),
              ),
              children: isExpanded
                  ? [
                      Card.filled(
                        margin: EdgeInsets.only(right: Platform.isAndroid ? 8 : 30, left: 8, bottom: 6, top: 4),
                        color: Colors.black12,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Acceleration: ${roundToDigits(widget.instruction.acceleration * 100, 2)}cm/s²"),
                              Slider(
                                value: accelSliderValue,
                                onChanged: (value) {
                                  widget.instruction.acceleration = roundToDigits(value, 3);
                                  widget.change(widget.instruction);
                                },
                                max: accelSliderMax,
                              ),
                              Text("Target Velocity: ${roundToDigits(widget.instruction.targetVelocity * 100, 2)}cm/s"),
                              Slider(
                                value: velSliderValue,
                                onChanged: (value) {
                                  widget.instruction.targetVelocity = roundToDigits(value, 3);
                                  widget.change(widget.instruction);
                                },
                                min: 0.001,
                                max: velSliderMax,
                              ),
                              ...widget.children,
                            ],
                          ),
                        ),
                      ),
                      if (widget.instructionResult.totalTime > 0) ...[
                        Card.filled(
                          color: Colors.black12,
                          margin: EdgeInsets.only(right: Platform.isAndroid ? 8 : 30, left: 8, bottom: 8, top: 6),
                          child: Padding(
                            padding: Platform.isAndroid ? const EdgeInsets.all(16) : const EdgeInsets.only(left: 16, right: 30, top: 16, bottom: 16),
                            child: InstructionDetailsWidget(
                              instructionResult: widget.instructionResult,
                              robiConfig: widget.robiConfig,
                              timeChangeNotifier: widget.timeChangeNotifier,
                            ),
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
