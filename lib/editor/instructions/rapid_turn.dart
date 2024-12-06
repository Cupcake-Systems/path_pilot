import 'package:flutter/material.dart';
import 'package:path_pilot/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';

class RapidTurnInstructionEditor extends AbstractEditor {
  @override
  final RapidTurnInstruction instruction;

  RapidTurnInstructionEditor({
    super.key,
    required this.instruction,
    required super.simulationResult,
    required super.instructionIndex,
    required super.change,
    required super.removed,
    required super.entered,
    required super.exited,
    required super.robiConfig,
    required super.timeChangeNotifier,
    required super.nextInstruction,
  }) : super(instruction: instruction);

  @override
  Widget build(BuildContext context) {
    const turnDegreeSliderMax = 360.0;
    final turnDegreeSliderValue = instruction.turnDegree > turnDegreeSliderMax ? turnDegreeSliderMax : instruction.turnDegree;

    return RemovableWarningCard(
      timeChangeNotifier: timeChangeNotifier,
      robiConfig: robiConfig,
      change: change,
      entered: entered,
      exited: exited,
      instruction: instruction,
      warningMessage: warningMessage,
      removed: removed,
      instructionResult: instructionResult,
      header: Card.filled(
        color: Colors.black12,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            children: [
              Icon(instruction.left ? Icons.turn_left : Icons.turn_right, size: 18),
              const SizedBox(width: 8),
              Text(
                "${instruction.left ? "Left" : "Right"} Rapid Turn ${instruction.turnDegree.round()}°",
                overflow: TextOverflow.fade,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      children: [
         Text("Turn Angle: ${instruction.turnDegree.round()}°"),
        Slider(
          value: turnDegreeSliderValue,
          onChanged: (value) {
            instruction.turnDegree = value.roundToDouble();
            change(instruction);
          },
          max: turnDegreeSliderMax,
        ),
         Text("Turn Direction: ${instruction.left ? "Left" : "Right"}"),
        Switch(
          value: !instruction.left,
          onChanged: (value) {
            instruction.left = !value;
            change(instruction);
          },
        ),
      ],
    );
  }
}
