import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';

import '../../robi_api/robi_utils.dart';
import '../add_instruction_dialog.dart';
import '../editor.dart';

class StopEditor extends AbstractEditor {
  @override
  final StopOverTimeInstruction instruction;

  StopEditor({
    super.key,
    required this.instruction,
    required super.simulationResult,
    required super.instructionIndex,
    required super.change,
    required super.entered,
    required super.exited,
  }) : super(instruction: instruction);

  @override
  Widget build(BuildContext context) {
    return RemovableWarningCard(
      instruction: instruction,
      entered: entered,
      exited: exited,
      prevResult: prevInstructionResult,
      instructionResult: instructionResult,
      children: [
        Icon(userInstructionToIcon[UserInstruction.stop]),
        const SizedBox(width: 10),
        const Text("Stop within "),
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
        const Text("s"),
      ],
    );
  }
}
