import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';
import '../editor.dart';

class DriveInstructionEditor extends AbstractEditor {
  @override
  final DriveForwardInstruction instruction;

  DriveInstructionEditor({
    super.key,
    required this.instruction,
    required super.simulationResult,
    required super.instructionIndex,
    required super.change,
    required super.removed,
  }) : super(instruction: instruction) {
    if (!isLastInstruction &&
        prevInstructionResult.managedVelocity <= 0 &&
        instruction.targetVelocity <= 0) {
      warningMessage = "Zero velocity";
    } else if ((instruction.targetVelocity - instructionResult.managedVelocity)
            .abs() >
        0.000001) {
      warningMessage =
          "Robi will only reach ${(instructionResult.managedVelocity * 100).toStringAsFixed(2)} cm/s";
    } else {
      warningMessage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RemovableWarningCard(
      instruction: instruction,
      warningMessage: warningMessage,
      removed: removed,
      prevResult: prevInstructionResult,
      instructionResult: instructionResult,
      children: [
        const Icon(Icons.arrow_upward),
        const SizedBox(width: 10),
        const Text("Drive "),
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
        const Text("m with a targeted velocity of "),
        IntrinsicWidth(
          child: TextFormField(
            style: const TextStyle(fontSize: 14),
            initialValue: "${instruction.targetVelocity * 100}",
            onChanged: (String? value) {
              if (value == null || value.isEmpty) return;
              final tried = double.tryParse(value);
              if (tried == null) return;
              instruction.targetVelocity = tried / 100.0;
              change(instruction);
            },
            inputFormatters: inputFormatters,
          ),
        ),
        const Text("cm/s accelerating at "),
        IntrinsicWidth(
          child: TextFormField(
            style: const TextStyle(fontSize: 14),
            initialValue: "${instruction.acceleration * 100}",
            onChanged: (String? value) {
              if (value == null || value.isEmpty) return;
              final tried = double.tryParse(value);
              if (tried == null) return;
              instruction.acceleration = tried / 100.0;
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
