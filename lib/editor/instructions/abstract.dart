import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:robi_line_drawer/editor/editor.dart';
import 'package:robi_line_drawer/robi_api/robi_path_serializer.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../../robi_api/robi_utils.dart';

abstract class AbstractEditor extends StatelessWidget {
  final MissionInstruction instruction;
  final SimulationResult simulationResult;
  final int instructionIndex;

  late final InstructionResult prevInstructionResult;
  late final InstructionResult instructionResult;
  late final bool isLastInstruction;

  final Function(MissionInstruction newInstruction) change;
  final Function() removed;

  String? warningMessage;

  AbstractEditor(
      {super.key,
      required this.instruction,
      required this.simulationResult,
      required this.instructionIndex,
      required this.change,
      required this.removed,
      this.warningMessage}) {
    if (instructionIndex > 0) {
      prevInstructionResult = simulationResult.instructionResults
              .elementAtOrNull(instructionIndex - 1) ??
          startResult;
    } else {
      prevInstructionResult = startResult;
    }

    instructionResult = simulationResult.instructionResults[instructionIndex];
    isLastInstruction =
        instructionIndex == simulationResult.instructionResults.length - 1;

    if (isLastInstruction && instructionResult.managedVelocity > 0) {
      warningMessage = "Robi will not stop at the end";
    }
  }
}

class RemovableWarningCard extends StatelessWidget {
  final Function() removed;

  final List<Widget> children;

  final InstructionResult prevResult;
  final InstructionResult instructionResult;

  final String? warningMessage;

  const RemovableWarningCard(
      {super.key,
      required this.children,
      required this.removed,
      required this.warningMessage,
      required this.prevResult,
      required this.instructionResult});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ExpandablePanel(
            header: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                ),
                IconButton(onPressed: removed, icon: const Icon(Icons.delete)),
                const SizedBox(width: 40),
              ],
            ),
            collapsed: const SizedBox.shrink(),
            expanded: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "Initial Velocity: ${roundToDigits(prevResult.managedVelocity * 100, 2)}cm/s"),
                      Text(
                          "Initial Position: ${vecToString(prevResult.endPosition, 2)}m"),
                      Text(
                          "Initial Rotation: ${roundToDigits(prevResult.endRotation, 2)}°"),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "End Velocity: ${roundToDigits(instructionResult.managedVelocity * 100, 2)}cm/s"),
                      Text(
                          "End Position: ${vecToString(instructionResult.endPosition, 2)}m"),
                      Text(
                          "End Rotation: ${roundToDigits(instructionResult.endRotation, 2)}°"),
                    ],
                  ),
                ],
              ),
            ),
            theme: const ExpandableThemeData(
                iconPlacement: ExpandablePanelIconPlacement.left,
                inkWellBorderRadius: BorderRadius.all(Radius.circular(10)),
                iconColor: Colors.white),
          ),
          if (warningMessage != null) ...[
            const Divider(height: 0),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(10)),
                  color: Colors.yellow.withAlpha(50)),
              child: Row(
                children: [
                  const Icon(Icons.warning),
                  const SizedBox(width: 10),
                  Text(warningMessage!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String vecToString(Vector2 vec, int decimalPlaces) {
    return "(${roundToDigits(vec.x, decimalPlaces)}, ${roundToDigits(vec.y, decimalPlaces)})";
  }
}
