import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robi_line_drawer/editor/add_instruction_dialog.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';
import 'package:robi_line_drawer/editor/instructions/accelerate_over_distance.dart';
import 'package:robi_line_drawer/editor/instructions/decelerate_over_distance.dart';
import 'package:robi_line_drawer/editor/instructions/decelerate_over_time.dart';
import 'package:robi_line_drawer/editor/instructions/drive_distance.dart';
import 'package:robi_line_drawer/editor/instructions/drive_time.dart';
import 'package:robi_line_drawer/editor/instructions/stop.dart';
import 'package:robi_line_drawer/file_browser.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:robi_line_drawer/editor/visualizer.dart';

import '../robi_api/robi_path_serializer.dart';
import '../robi_api/simulator.dart';
import 'instructions/accelerate_over_time.dart';
import 'instructions/drive.dart';
import 'instructions/turn.dart';

final inputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'^(\d+)?\.?\d{0,5}'))
];

class Editor extends StatefulWidget {
  final List<MissionInstruction> instructions;
  final RobiConfig robiConfig;
  final void Function() exportPressed;
  final void Function(List<MissionInstruction> instructions)
      instructionsChanged;

  const Editor({
    super.key,
    required this.instructions,
    required this.robiConfig,
    required this.exportPressed,
    required this.instructionsChanged,
  });

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  late SimulationResult simulationResult;
  late List<MissionInstruction> instructions = widget.instructions;
  double scale = 200;
  late Simulator simulator = Simulator(widget.robiConfig);

  @override
  void initState() {
    super.initState();
    simulationResult = simulator.calculate(instructions);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Visualizer(
            simulationResult: simulationResult,
            key: ValueKey(simulationResult),
            scale: scale,
            scaleChanged: (newScale) => scale = newScale,
            robiConfig: widget.robiConfig,
          ),
        ),
        const VerticalDivider(width: 0),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                AppBar(title: const Text("Instructions Editor")),
                const Divider(),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: instructions.length - 1,
                    header: const Card(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 40),
                        child: Row(
                          children: [
                            Icon(Icons.start),
                            SizedBox(width: 10),
                            Text("Start"),
                          ],
                        ),
                      ),
                    ),
                    footer: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Card.outlined(
                                child: IconButton(
                                  style: IconButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  icon: const Icon(Icons.add),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (BuildContext context) =>
                                        AddInstructionDialog(
                                      instructionAdded:
                                          (MissionInstruction instruction) {
                                        instructions.insert(
                                            instructions.length - 1,
                                            instruction);
                                        rerunSimulationAndUpdate();
                                      },
                                      simulationResult: simulationResult,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Card.outlined(
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 30),
                                onPressed: () {
                                  instructions.clear();
                                  instructions.add(defaultStopInstruction());
                                  rerunSimulationAndUpdate();
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                        StopEditor(
                          instruction:
                              instructions.last as StopOverTimeInstruction,
                          simulationResult: simulationResult,
                          instructionIndex: instructions.length - 1,
                          change: (newInstruction) {
                            instructions[instructions.length - 1] =
                                newInstruction;
                            rerunSimulationAndUpdate();
                          },
                        )
                      ],
                    ),
                    itemBuilder: (context, i) => instructionToEditor(i),
                    onReorder: (int oldIndex, int newIndex) {
                      if (oldIndex < newIndex) newIndex -= 1;
                      instructions.insert(
                          newIndex, instructions.removeAt(oldIndex));
                      rerunSimulationAndUpdate();
                    },
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton.filledTonal(
                      onPressed: simulationResult.instructionResults.isEmpty
                          ? null
                          : widget.exportPressed,
                      icon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [Text("Export"), Icon(Icons.chevron_right)],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  AbstractEditor instructionToEditor(int i) {
    final instruction = instructions[i];

    void changeCallback(MissionInstruction newInstruction) {
      instructions[i] = newInstruction;
      rerunSimulationAndUpdate();
    }

    void removedCallback() {
      instructions.removeAt(i);
      rerunSimulationAndUpdate();
    }

    if (instruction is AccelerateOverDistanceInstruction) {
      if (instruction.acceleration > 0) {
        return AccelerateOverDistanceEditor(
          key: Key("$i"),
          instruction: instruction,
          change: changeCallback,
          removed: removedCallback,
          simulationResult: simulationResult,
          instructionIndex: i,
        );
      } else {
        return DecelerateOverDistanceEditor(
          key: Key("$i"),
          instruction: instruction,
          simulationResult: simulationResult,
          instructionIndex: i,
          change: changeCallback,
          removed: removedCallback,
        );
      }
    } else if (instruction is AccelerateOverTimeInstruction) {
      if (instruction.acceleration > 0) {
        return AccelerateOverTimeEditor(
          key: Key("$i"),
          instruction: instruction,
          change: changeCallback,
          removed: removedCallback,
          simulationResult: simulationResult,
          instructionIndex: i,
        );
      } else {
        return DecelerateOverTimeEditor(
          key: Key("$i"),
          instruction: instruction,
          simulationResult: simulationResult,
          instructionIndex: i,
          change: changeCallback,
          removed: removedCallback,
        );
      }
    } else if (instruction is DriveForwardInstruction) {
      return DriveInstructionEditor(
        key: Key("$i"),
        instruction: instruction,
        change: changeCallback,
        removed: removedCallback,
        simulationResult: simulationResult,
        instructionIndex: i,
      );
    } else if (instruction is TurnInstruction) {
      return TurnInstructionEditor(
        key: Key("$i"),
        instruction: instruction,
        change: changeCallback,
        removed: removedCallback,
        simulationResult: simulationResult,
        instructionIndex: i,
        robiConfig: widget.robiConfig,
      );
    } else if (instruction is DriveForwardDistanceInstruction) {
      return DriveDistanceEditor(
        key: Key("$i"),
        instruction: instruction,
        simulationResult: simulationResult,
        instructionIndex: i,
        change: changeCallback,
        removed: removedCallback,
      );
    } else if (instruction is DriveForwardTimeInstruction) {
      return DriveTimeEditor(
        key: Key("$i"),
        instruction: instruction,
        simulationResult: simulationResult,
        instructionIndex: i,
        change: changeCallback,
        removed: removedCallback,
      );
    }
    throw UnsupportedError("");
  }

  void rerunSimulationAndUpdate() {
    List<MissionInstruction> newInstructions = [];

    for (final instruction in instructions) {
      final simResult = simulator.calculate(newInstructions);

      InstructionResult prevInstResult =
          simResult.instructionResults.lastOrNull ?? startResult;

      if (instruction is DriveInstruction) {
        if (instruction.runtimeType == DriveForwardInstruction) {
          newInstructions.add(DriveForwardInstruction(instruction.distance,
              instruction.targetVelocity, instruction.acceleration));
        } else if (instruction is AccelerateOverDistanceInstruction) {
          newInstructions.add(AccelerateOverDistanceInstruction(
            initialVelocity: prevInstResult.managedVelocity,
            distance: instruction.distance,
            acceleration: instruction.acceleration,
          ));
        } else if (instruction is AccelerateOverTimeInstruction) {
          if (instruction is StopOverTimeInstruction) {
            newInstructions.add(StopOverTimeInstruction(
                prevInstResult.managedVelocity, instruction.time));
          } else {
            newInstructions.add(AccelerateOverTimeInstruction(
              prevInstResult.managedVelocity,
              instruction.time,
              instruction.acceleration,
            ));
          }
        } else if (instruction is DriveForwardDistanceInstruction) {
          newInstructions.add(DriveForwardDistanceInstruction(
              instruction.distance, prevInstResult.managedVelocity));
        } else if (instruction is DriveForwardTimeInstruction) {
          newInstructions.add(DriveForwardTimeInstruction(
              instruction.time, prevInstResult.managedVelocity));
        } else {
          throw UnsupportedError("");
        }
      } else if (instruction is TurnInstruction) {
        newInstructions.add(TurnInstruction(
            instruction.turnDegree, instruction.left, instruction.radius));
      } else {
        throw UnsupportedError("");
      }
    }

    setState(() {
      instructions = newInstructions;
      simulationResult = simulator.calculate(instructions);
    });

    widget.instructionsChanged(instructions);
  }
}

double roundToDigits(double num, int digits) {
  final e = pow(10, digits);
  return (num * e).roundToDouble() / e;
}
