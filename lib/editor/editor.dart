import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robi_line_drawer/editor/instructions/accelerate_over_distance.dart';
import 'package:robi_line_drawer/editor/instructions/decelerate_over_distance.dart';
import 'package:robi_line_drawer/editor/instructions/drive_distance.dart';
import 'package:robi_line_drawer/editor/instructions/drive_time.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:robi_line_drawer/editor/visualizer.dart';

import '../robi_api/robi_path_serializer.dart';
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

  const Editor(
      {super.key,
      required this.instructions,
      required this.robiConfig,
      required this.exportPressed});

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

  static const Map<UserInstruction, IconData> userInstructionToIcon = {
    UserInstruction.drive: Icons.arrow_upward,
    UserInstruction.turn: Icons.turn_right,
    UserInstruction.accelerateOverDistance: Icons.speed,
    UserInstruction.accelerateOverTime: Icons.speed,
    UserInstruction.driveDistance: Icons.arrow_upward,
    UserInstruction.driveTime: Icons.arrow_upward,
    UserInstruction.decelerateOverDistance: Icons.speed,
  };

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
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: instructions.length,
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
                    footer: Card.outlined(
                      child: IconButton(
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        icon: const Icon(Icons.add),
                        onPressed: () => showDialog<AvailableInstruction?>(
                          context: context,
                          builder: (BuildContext context) {
                            UserInstruction selectedInstruction =
                                UserInstruction.drive;

                            return StatefulBuilder(
                                builder: (context, setState) {
                              RadioListTile createRadioButtonForAdd(
                                  UserInstruction value) {
                                final IconData? icon =
                                    userInstructionToIcon[value];
                                return RadioListTile<UserInstruction>(
                                  title: ListTile(
                                    title: Text(camelToSentence(value.name)),
                                    leading: Icon(icon),
                                  ),
                                  value: value,
                                  groupValue: selectedInstruction,
                                  onChanged: (v) =>
                                      setState(() => selectedInstruction = v!),
                                );
                              }

                              return AlertDialog(
                                title: const Text("Add Instruction"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final t in baseInstructions) ...[
                                      createRadioButtonForAdd(t),
                                    ],
                                    const Divider(),
                                    for (final t
                                        in withoutBaseInstructions) ...[
                                      createRadioButtonForAdd(t),
                                    ],
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      addInstruction(
                                          selectedInstruction,
                                          simulationResult.instructionResults
                                                  .lastOrNull ??
                                              startResult,
                                          simulationResult.instructionResults
                                                  .lastWhere(
                                                      (e) => e is DriveResult,
                                                      orElse: () => startResult)
                                              as DriveResult);
                                    },
                                    child: const Text("Ok"),
                                  ),
                                ],
                              );
                            });
                          },
                        ),
                      ),
                    ),
                    itemBuilder: (context, i) {
                      final instruction = instructions[i];

                      if (instruction.runtimeType ==
                          AccelerateOverDistanceInstruction) {
                        final inst =
                            instruction as AccelerateOverDistanceInstruction;
                        if (inst.acceleration > 0) {
                          return AccelerateOverDistanceEditor(
                            key: Key("$i"),
                            instruction: inst,
                            change: (newInstruction) {
                              instructions[i] = newInstruction;
                              rerunSimulationAndUpdate();
                            },
                            removed: () {
                              instructions.removeAt(i);
                              rerunSimulationAndUpdate();
                            },
                            simulationResult: simulationResult,
                            instructionIndex: i,
                          );
                        }
                        return DecelerateOverDistanceEditor(
                          key: Key("$i"),
                          instruction: inst,
                          simulationResult: simulationResult,
                          instructionIndex: i,
                          change: (newInstruction) {
                            instructions[i] = newInstruction;
                            rerunSimulationAndUpdate();
                          },
                          removed: () {
                            instructions.removeAt(i);
                            rerunSimulationAndUpdate();
                          },
                        );
                      } else if (instruction.runtimeType ==
                          AccelerateOverTimeInstruction) {
                        return AccelerateOverTimeEditor(
                          key: Key("$i"),
                          instruction:
                              instruction as AccelerateOverTimeInstruction,
                          change: (newInstruction) {
                            instructions[i] = newInstruction;
                            rerunSimulationAndUpdate();
                          },
                          removed: () {
                            instructions.removeAt(i);
                            rerunSimulationAndUpdate();
                          },
                          simulationResult: simulationResult,
                          instructionIndex: i,
                        );
                      } else if (instruction.runtimeType ==
                          DriveForwardInstruction) {
                        return DriveInstructionEditor(
                          key: Key(i.toString()),
                          instruction: instruction as DriveForwardInstruction,
                          change: (newInstruction) {
                            instructions[i] = newInstruction;
                            rerunSimulationAndUpdate();
                          },
                          removed: () {
                            instructions.removeAt(i);
                            rerunSimulationAndUpdate();
                          },
                          simulationResult: simulationResult,
                          instructionIndex: i,
                        );
                      } else if (instruction.runtimeType == TurnInstruction) {
                        return TurnInstructionEditor(
                          key: Key("$i"),
                          instruction: instruction as TurnInstruction,
                          change: (newInstruction) {
                            instructions[i] = newInstruction;
                            rerunSimulationAndUpdate();
                          },
                          removed: () {
                            instructions.removeAt(i);
                            rerunSimulationAndUpdate();
                          },
                          simulationResult: simulationResult,
                          instructionIndex: i,
                          robiConfig: widget.robiConfig,
                        );
                      } else if (instruction.runtimeType ==
                          DriveForwardDistanceInstruction) {
                        return DriveDistanceEditor(
                          key: Key("$i"),
                          instruction:
                              instruction as DriveForwardDistanceInstruction,
                          simulationResult: simulationResult,
                          instructionIndex: i,
                          change: (newInstruction) {
                            instructions[i] = newInstruction;
                            rerunSimulationAndUpdate();
                          },
                          removed: () {
                            instructions.removeAt(i);
                            rerunSimulationAndUpdate();
                          },
                        );
                      } else if (instruction.runtimeType ==
                          DriveForwardTimeInstruction) {
                        return DriveTimeEditor(
                          key: Key("$i"),
                          instruction:
                              instruction as DriveForwardTimeInstruction,
                          simulationResult: simulationResult,
                          instructionIndex: i,
                          change: (newInstruction) {
                            instructions[i] = newInstruction;
                            rerunSimulationAndUpdate();
                          },
                          removed: () {
                            instructions.removeAt(i);
                            rerunSimulationAndUpdate();
                          },
                        );
                      }
                      throw UnsupportedError("");
                    },
                    onReorder: (int oldIndex, int newIndex) {
                      if (oldIndex < newIndex) newIndex -= 1;
                      instructions.insert(
                          newIndex, instructions.removeAt(oldIndex));
                      rerunSimulationAndUpdate();
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        instructions.clear();
                        rerunSimulationAndUpdate();
                      },
                      label: const Text("Clear"),
                      icon: const Icon(Icons.delete),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      iconAlignment: IconAlignment.end,
                      onPressed: simulationResult.instructionResults.isEmpty
                          ? null
                          : widget.exportPressed,
                      label: const Text("Export"),
                      icon: const Icon(Icons.chevron_right),
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
          newInstructions.add(AccelerateOverTimeInstruction(
            prevInstResult.managedVelocity,
            instruction.time,
            instruction.acceleration,
          ));
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
  }

  void addInstruction(UserInstruction instruction,
      InstructionResult prevInstResult, DriveResult lastDriveResult) {
    MissionInstruction inst;

    switch (instruction) {
      case UserInstruction.driveDistance:
        inst = DriveForwardDistanceInstruction(
            0.5, prevInstResult.managedVelocity);
        break;
      case UserInstruction.accelerateOverDistance:
        inst = AccelerateOverDistanceInstruction(
            initialVelocity: prevInstResult.managedVelocity,
            distance: 0.5,
            acceleration: 0.3);
        break;
      case UserInstruction.drive:
        double targetVel = 0.5;
        double acceleration = 0.3;

        if (prevInstResult is TurnResult) {
          targetVel = lastDriveResult.managedVelocity;
        }

        if (prevInstResult.managedVelocity > targetVel) {
          acceleration = -acceleration;
        }

        inst = DriveForwardInstruction(
            1, roundToDigits(targetVel, 2), acceleration);
        break;
      case UserInstruction.turn:
        inst = TurnInstruction(90, false, 0.1);
        break;
      case UserInstruction.accelerateOverTime:
        inst = AccelerateOverTimeInstruction(
            prevInstResult.managedVelocity, 1, 0.3);
        break;
      case UserInstruction.driveTime:
        inst = DriveForwardTimeInstruction(1, prevInstResult.managedVelocity);
        break;
      case UserInstruction.decelerateOverDistance:
        inst = AccelerateOverDistanceInstruction(
            initialVelocity: prevInstResult.managedVelocity,
            distance: 0.5,
            acceleration: -0.3);
        break;
    }

    instructions.add(inst);
    rerunSimulationAndUpdate();
  }
}

double? asdf(TextEditingController controller, String? value) {
  if (value == null) return null;
  if (value.isEmpty) return 0;
  final parsed = double.tryParse(value);
  return parsed;
}

double roundToDigits(double num, int digits) {
  final e = pow(10, digits);
  return (num * e).roundToDouble() / e;
}

String camelToSentence(String text) => text.replaceAllMapped(
    RegExp(r'^([a-z])|[A-Z]'),
    (Match m) => m[1] == null ? " ${m[0]}" : m[1]!.toUpperCase());

enum UserInstruction {
  drive,
  turn,
  accelerateOverDistance,
  decelerateOverDistance,
  accelerateOverTime,
  driveDistance,
  driveTime,
}

const baseInstructions = [UserInstruction.drive, UserInstruction.turn];
final withoutBaseInstructions =
    UserInstruction.values.where((e) => !baseInstructions.contains(e));