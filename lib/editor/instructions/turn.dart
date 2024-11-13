import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';
import '../editor.dart';

class TurnInstructionEditor extends AbstractEditor {
  @override
  final TurnInstruction instruction;

  TurnInstructionEditor({
    super.key,
    required this.instruction,
    required super.simulationResult,
    required super.instructionIndex,
    required super.change,
    required super.removed,
    required super.entered,
    required super.exited,
    required super.robiConfig,
    required super.progress,
  }) : super(instruction: instruction);

  @override
  Widget build(BuildContext context) {
    return RemovableWarningCard(
      progress: progress,
      robiConfig: robiConfig,
      change: change,
      entered: entered,
      exited: exited,
      instruction: instruction,
      warningMessage: warningMessage,
      removed: removed,
      instructionResult: instructionResult,
      header: Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Icon(instruction.left ? Icons.turn_left : Icons.turn_right, size: 18),
              const SizedBox(width: 8),
              Text("${instruction.left ? "Left" : "Right"} Turn ${instruction.turnDegree.round()}°"),
            ],
          ),
        ),
      ),
      children: [
        TableRow(
          children: [
            const Text("Turn Degree"),
            Slider(
              value: instruction.turnDegree,
              onChanged: (value) {
                instruction.turnDegree = value.roundToDouble();
                change(instruction);
              },
              min: 0,
              max: 720,
            ),
            Text("${instruction.turnDegree.round()}°"),
          ],
        ),
        TableRow(
          children: [
            const Text("Inner Radius"),
            Slider(
              value: instruction.innerRadius,
              onChanged: (value) {
                instruction.innerRadius = roundToDigits(value, 3);
                change(instruction);
              },
            ),
            Text("${roundToDigits(instruction.innerRadius * 100, 2)}cm"),
          ],
        ),
        TableRow(
          children: [
            const Text("Turn"),
            Switch(
              value: !instruction.left,
              onChanged: (value) {
                instruction.left = !value;
                change(instruction);
              },
            ),
            Text(instruction.left ? "Left" : "Right"),
          ],
        ),
      ],
    );
  }
}
