import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';
import '../add_instruction_dialog.dart';
import '../editor.dart';

class DecelerateOverDistanceEditor extends AbstractEditor {
  @override
  final AccelerateOverDistanceInstruction instruction;

  DecelerateOverDistanceEditor({
    super.key,
    required this.instruction,
    required super.simulationResult,
    required super.instructionIndex,
    required super.change,
    required super.removed,
    required super.entered,
    required super.exited,
  }) : super(instruction: instruction) {
    if (instruction.acceleration >= 0 || instruction.distance <= 0) {
      warningMessage = "Pointless";
    } else if (prevInstructionResult.maxVelocity <= 0) {
      warningMessage = "Cannot decelerate further";
    } else if (instructionResult.endPosition
            .distanceTo(prevInstructionResult.endPosition) <
        instruction.distance) {
      warningMessage =
          "Robi will stop before reaching ${instruction.distance.toStringAsFixed(2)}m";
    }
  }

  @override
  Widget build(BuildContext context) {
    return RemovableWarningCard(
      instruction: instruction,
      warningMessage: warningMessage,
      removed: removed,
      entered: entered,
      exited: exited,
      prevResult: prevInstructionResult,
      instructionResult: instructionResult,
      children: [
        Icon(userInstructionToIcon[UserInstruction.decelerateOverDistance]),
        const SizedBox(width: 10),
        const Text("Decelerate over "),
        IntrinsicWidth(
          child: TextFormField(
            style: const TextStyle(fontSize: 14),
            initialValue: instruction.distance.toString(),
            onChanged: (String? value) {
              if (value == null || value.isEmpty) return;
              final tried = double.tryParse(value);
              if (tried == null) return;
              instruction.distance = tried;
              change(instruction);
            },
            inputFormatters: inputFormatters,
          ),
        ),
        const Text("m, at "),
        IntrinsicWidth(
          child: TextFormField(
            style: const TextStyle(fontSize: 14),
            initialValue: "${instruction.acceleration.abs() * 100}",
            onChanged: (String? value) {
              if (value == null || value.isEmpty) return;
              final tried = double.tryParse(value);
              if (tried == null) return;
              instruction.acceleration = -tried / 100;
              change(instruction);
            },
            inputFormatters: inputFormatters,
          ),
        ),
        const Text("cm/s²"),
      ],
    );
  }
}
