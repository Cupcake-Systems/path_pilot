import 'package:flutter/material.dart';
import 'package:path_pilot/editor/instructions/abstract.dart';

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
    required super.timeChangeNotifier,
    required super.nextInstruction,
  }) : super(instruction: instruction);

  @override
  Widget build(BuildContext context) {
    const turnDegreeSliderMax = 360.0;
    final turnDegreeSliderValue = instruction.turnDegree > turnDegreeSliderMax ? turnDegreeSliderMax : instruction.turnDegree;

    const innerRadiusSliderMax = 2.0;
    final innerRadiusSliderValue = instruction.innerRadius > innerRadiusSliderMax ? innerRadiusSliderMax : instruction.innerRadius;

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
              Text("${instruction.left ? "Left" : "Right"} Turn ${instruction.turnDegree.round()}°", overflow: TextOverflow.fade, maxLines: 2),
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
        Text("Inner Radius: ${roundToDigits(instruction.innerRadius * 100, 2)}cm"),
        Slider(
          value: innerRadiusSliderValue,
          onChanged: (value) {
            instruction.innerRadius = roundToDigits(value, 3);
            change(instruction);
          },
          max: innerRadiusSliderMax,
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
