import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';
import '../add_instruction_dialog.dart';
import '../editor.dart';

class DriveInstructionEditor extends AbstractEditor {
  @override
  final DriveInstruction instruction;

  DriveInstructionEditor({
    super.key,
    required this.instruction,
    required super.simulationResult,
    required super.instructionIndex,
    required super.change,
    required super.removed,
    required super.entered,
    required super.exited,
  }) : super(instruction: instruction);

  @override
  Widget build(BuildContext context) {
    return RemovableWarningCard(
      change: change,
      instruction: instruction,
      warningMessage: warningMessage,
      removed: removed,
      entered: entered,
      exited: exited,
      instructionResult: instructionResult,
      header: Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Icon(userInstructionToIcon[UserInstruction.drive], size: 18),
              const SizedBox(width: 8),
              Text("Drive ${(instruction.targetDistance * 100).round()}cm"),
            ],
          ),
        ),
      ),
      children: [
        TableRow(
          children: [
            const Text("Distance to drive"),
            Slider(
              value: instruction.targetDistance,
              onChanged: (value) {
                instruction.targetDistance = roundToDigits(value, 3);
                change(instruction);
              },
              max: 5,
            ),
            Text("${roundToDigits(instruction.targetDistance * 100, 2)}cm"),
          ],
        ),
      ],
    );
  }
}
