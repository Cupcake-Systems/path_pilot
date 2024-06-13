import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';
import '../editor.dart';

class AccelerateOverTimeEditor extends AbstractEditor {
  @override
  final AccelerateOverTimeInstruction instruction;

  AccelerateOverTimeEditor({
    super.key,
    required this.instruction,
    required super.simulationResult,
    required super.instructionIndex,
    required super.change,
    required super.removed,
  }) : super(instruction: instruction) {
    if (instruction.acceleration <= 0 || instruction.time <= 0) {
      warningMessage = "Pointless";
    }
  }

  @override
  Widget build(BuildContext context) {
    return RemovableWarningCard(
      instruction: instruction,
      instructionResult: instructionResult,
      prevResult: prevInstructionResult,
      removed: removed,
      warningMessage: warningMessage,
      children: [
        const Icon(Icons.speed),
        const SizedBox(width: 10),
        const Text("Accelerate over "),
        IntrinsicWidth(
          child: TextFormField(
            style: const TextStyle(fontSize: 14),
            initialValue: instruction.time.toString(),
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
        const Text("s, at "),
        IntrinsicWidth(
          child: TextFormField(
            style: const TextStyle(fontSize: 14),
            initialValue: "${instruction.acceleration * 100}",
            onChanged: (String? value) {
              if (value == null || value.isEmpty) return;
              final tried = double.tryParse(value);
              if (tried == null) return;
              instruction.acceleration = tried / 100;
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
