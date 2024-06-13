import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';
import '../editor.dart';

class DriveTimeEditor extends AbstractEditor {
  @override
  DriveForwardTimeInstruction instruction;

  DriveTimeEditor({
    super.key,
    required this.instruction,
    required super.simulationResult,
    required super.instructionIndex,
    required super.change,
    required super.removed,
  }) : super(instruction: instruction);

  @override
  Widget build(BuildContext context) {
    return RemovableWarningCard(
      removed: removed,
      warningMessage: warningMessage,
      prevResult: prevInstructionResult,
      instructionResult: instructionResult,
      instruction: instruction,
      children: [
        const Icon(Icons.arrow_upward),
        const SizedBox(width: 10),
        const Text("Drive for "),
        IntrinsicWidth(
          child: TextFormField(
            style: const TextStyle(fontSize: 14),
            initialValue: instruction.distance.toString(),
            onChanged: (String? value) {
              if (value == null || value.isEmpty) return;
              final tried = double.tryParse(value);
              if (tried == null) return;
              instruction.time = tried;
              change(instruction);
            },
            inputFormatters: inputFormatters,
          ),
        ),
        const Text("s")
      ],
    );
  }
}
