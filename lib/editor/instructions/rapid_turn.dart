import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';
import '../editor.dart';

class RapidTurnInstructionEditor extends AbstractEditor {
  @override
  final RapidTurnInstruction instruction;
  final RobiConfig robiConfig;

  RapidTurnInstructionEditor({
    super.key,
    required this.instruction,
    required this.robiConfig,
    required super.simulationResult,
    required super.instructionIndex,
    required super.change,
    required super.removed,
    required super.entered,
    required super.exited,
  }) : super(instruction: instruction) {
    if (prevInstructionResult.maxVelocity <= 0) {
      warningMessage = "Zero velocity";
    }
  }

  @override
  Widget build(BuildContext context) {
    return RemovableWarningCard(
      entered: entered,
      exited: exited,
      instruction: instruction,
      warningMessage: warningMessage,
      removed: removed,
      prevResult: prevInstructionResult,
      instructionResult: instructionResult,
      children: [
        Icon(instruction.turnDegree > 0 ? Icons.turn_left : Icons.turn_right),
        const SizedBox(width: 10),
        const Text("Turn "),
        IntrinsicWidth(
          child: TextFormField(
            style: const TextStyle(fontSize: 14),
            initialValue: instruction.turnDegree.abs().toString(),
            onChanged: (String? value) {
              if (value == null || value.isEmpty) return;
              final tried = double.tryParse(value);
              if (tried == null) return;
              instruction.turnDegree = tried;
              change(instruction);
            },
            inputFormatters: inputFormatters,
          ),
        ),
        const Text("° to the "),
        DropdownMenu(
          textStyle: const TextStyle(fontSize: 14),
          width: 100,
          inputDecorationTheme: const InputDecorationTheme(),
          initialSelection: instruction.turnDegree,
          onSelected: (double? value) {
            instruction.turnDegree = value!;
            change(instruction);
          },
          dropdownMenuEntries: [
            DropdownMenuEntry(
                value: instruction.turnDegree.abs(), label: "left"),
            DropdownMenuEntry(
                value: -instruction.turnDegree.abs(), label: "right"),
          ],
        ),
      ],
    );
  }
}
