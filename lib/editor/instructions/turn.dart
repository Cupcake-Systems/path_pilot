import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';
import '../editor.dart';

class TurnInstructionEditor extends AbstractEditor {
  @override
  final TurnInstruction instruction;
  final RobiConfig robiConfig;

  TurnInstructionEditor(
      {super.key,
      required this.instruction,
      required this.robiConfig,
      required super.simulationResult,
      required super.instructionIndex,
      required super.change,
      required super.removed})
      : super(instruction: instruction) {
    if (prevInstructionResult.managedVelocity <= 0) {
      warningMessage = "Zero velocity";
    } else {
      warningMessage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return RemovableWarningCard(
            warningMessage: warningMessage,
            removed: removed,
            prevResult: prevInstructionResult,
            instructionResult: instructionResult,
            children: [
              Icon(instruction.left ? Icons.turn_left : Icons.turn_right),
              const SizedBox(width: 10),
              const Text("Turn "),
              IntrinsicWidth(
                child: TextFormField(
                  style: const TextStyle(fontSize: 14),
                  initialValue: instruction.turnDegree.toString(),
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
                initialSelection: instruction.left,
                onSelected: (bool? value) {
                  instruction.left = value!;
                  change(instruction);
                },
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: true, label: "left"),
                  DropdownMenuEntry(value: false, label: "right"),
                ],
              ),
              const Text("with a "),
              IntrinsicWidth(
                child: TextFormField(
                  style: const TextStyle(fontSize: 14),
                  initialValue: "${instruction.radius * 100}",
                  onChanged: (String? value) {
                    if (value == null || value.isEmpty) return;
                    final tried = double.tryParse(value);
                    if (tried == null) return;
                    instruction.radius = tried / 100;
                    change(instruction);
                  },
                  inputFormatters: inputFormatters,
                ),
              ),
              const Text("cm inner radius")
            ]);
      },
    );
  }
}
