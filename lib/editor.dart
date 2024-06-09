import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robi_line_drawer/robi_utils.dart';
import 'package:robi_line_drawer/visualizer.dart';

import 'robi_path_serializer.dart';

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
  late final List<MissionInstruction> instructions = widget.instructions;
  double scale = 200;

  @override
  void initState() {
    super.initState();
    simulationResult = Simulator(widget.robiConfig).calculate(instructions);
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
                            AvailableInstruction selectedInstruction =
                                AvailableInstruction.driveInstruction;
                            return StatefulBuilder(
                                builder: (context, setState) {
                              return AlertDialog(
                                title: const Text("Add Instruction"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    RadioListTile<AvailableInstruction>(
                                      title: const ListTile(
                                        title: Text("Drive"),
                                        leading: Icon(Icons.arrow_upward),
                                      ),
                                      value:
                                          AvailableInstruction.driveInstruction,
                                      groupValue: selectedInstruction,
                                      onChanged: (value) => setState(
                                          () => selectedInstruction = value!),
                                    ),
                                    RadioListTile<AvailableInstruction>(
                                      title: const ListTile(
                                        title: Text("Turn"),
                                        leading: Icon(Icons.turn_right),
                                      ),
                                      value:
                                          AvailableInstruction.turnInstruction,
                                      groupValue: selectedInstruction,
                                      onChanged: (value) => setState(
                                          () => selectedInstruction = value!),
                                    ),
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
                                      addInstruction(selectedInstruction);
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

                      Widget w;

                      if (instruction is DriveInstruction) {
                        w = DriveInstructionEditor(
                          key: Key(i.toString()),
                          instruction: instruction,
                          textChanged: (newInstruction) {
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
                      } else if (instruction is TurnInstruction) {
                        w = TurnInstructionEditor(
                          key: Key("$i$simulationResult"),
                          instruction: instruction,
                          textChanged: (newInstruction) {
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
                      } else {
                        throw UnsupportedError("");
                      }
                      return w;
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

  void rerunSimulationAndUpdate() => setState(() =>
      simulationResult = Simulator(widget.robiConfig).calculate(instructions));

  void addInstruction(AvailableInstruction instruction) {
    MissionInstruction inst;
    switch (instruction) {
      case AvailableInstruction.driveInstruction:
        inst = DriveInstruction(1, 0.5, 0.3);
        break;
      case AvailableInstruction.turnInstruction:
        inst = TurnInstruction(90, false, 0.1);
        break;
    }
    setState(() => instructions.add(inst));
    rerunSimulationAndUpdate();
  }
}

double? asdf(TextEditingController controller, String? value) {
  if (value == null) return null;
  if (value.isEmpty) return 0;
  final parsed = double.tryParse(value);
  return parsed;
}

class DriveInstructionEditor extends StatelessWidget {
  final DriveInstruction instruction;
  final SimulationResult simulationResult;
  final int instructionIndex;

  final Function(DriveInstruction newInstruction) textChanged;
  final Function() removed;

  late final String? warningMessage;

  DriveInstructionEditor(
      {super.key,
      required this.instruction,
      required this.textChanged,
      required this.removed,
      required this.simulationResult,
      required this.instructionIndex}) {
    final instructionResult =
        simulationResult.instructionResults[instructionIndex];
    final prevResult =
        simulationResult.instructionResults.elementAtOrNull(instructionIndex) ??
            startResult;

    final isLastInstruction =
        instructionIndex == simulationResult.instructionResults.length - 1;

    if (!isLastInstruction &&
        prevResult.managedVelocity <= 0 &&
        instruction.targetVelocity <= 0) {
      warningMessage = "Zero velocity";
    } else if ((instruction.targetVelocity - instructionResult.managedVelocity)
            .abs() >
        0.000001) {
      warningMessage =
          "Robi will only reach ${(instructionResult.managedVelocity * 100).toStringAsFixed(2)} cm/s";
    } else if (isLastInstruction && instructionResult.managedVelocity > 0) {
      warningMessage = "Robi will not stop at the end";
    } else {
      warningMessage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.only(right: 40, left: 10, top: 5, bottom: 5),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                            textChanged(instruction);
                          },
                          inputFormatters: inputFormatters,
                        ),
                      ),
                      const SizedBox(width: 10),
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
                            textChanged(instruction);
                          },
                          inputFormatters: inputFormatters,
                        ),
                      ),
                      const Text("cm/s accelerating at"),
                      const SizedBox(width: 10),
                      IntrinsicWidth(
                        child: TextFormField(
                          style: const TextStyle(fontSize: 14),
                          initialValue: "${instruction.acceleration * 100}",
                          onChanged: (String? value) {
                            if (value == null || value.isEmpty) return;
                            final tried = double.tryParse(value);
                            if (tried == null) return;
                            instruction.acceleration = tried / 100.0;
                            textChanged(instruction);
                          },
                          inputFormatters: inputFormatters,
                        ),
                      ),
                      const Text("cm/s²"),
                    ],
                  ),
                ),
                IconButton(onPressed: removed, icon: const Icon(Icons.delete))
              ],
            ),
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
          ]
        ],
      ),
    );
  }

  TextField createTextField(TextEditingController controller, String hint,
      Function(double value) setValue, double Function() getValue) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(hintText: hint),
      onChanged: (String? value) {
        final res = asdf(controller, value);
        if (res == null) {
          controller.text = getValue().toString();
          return;
        }
        setValue(res);
        textChanged(instruction);
      },
    );
  }
}

class TurnInstructionEditor extends StatefulWidget {
  final TurnInstruction instruction;
  final SimulationResult simulationResult;
  final int instructionIndex;
  final RobiConfig robiConfig;

  final Function() removed;
  final Function(TurnInstruction newInstruction) textChanged;

  const TurnInstructionEditor(
      {super.key,
      required this.instruction,
      required this.textChanged,
      required this.removed,
      required this.simulationResult,
      required this.instructionIndex,
      required this.robiConfig});

  @override
  State<TurnInstructionEditor> createState() => _TurnInstructionEditorState();
}

class _TurnInstructionEditorState extends State<TurnInstructionEditor> {
  late final TextEditingController rotation =
      TextEditingController(text: widget.instruction.turnDegree.toString());

  String? warningMessage;

  @override
  Widget build(BuildContext context) {
    final turnResult = widget.simulationResult
        .instructionResults[widget.instructionIndex] as TurnResult;

    final prevResult = widget.simulationResult.instructionResults
            .elementAtOrNull(widget.instructionIndex) ??
        startResult;

    if (widget.instructionIndex ==
            widget.simulationResult.instructionResults.length - 1 &&
        turnResult.managedVelocity > 0) {
      warningMessage = "Robi will not stop at the end";
    } else if (prevResult.managedVelocity <= 0) {
      warningMessage = "Zero velocity";
    } else {
      warningMessage = null;
    }

    return Card(
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.only(right: 40, left: 10, top: 5, bottom: 5),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(widget.instruction.left
                          ? Icons.turn_left
                          : Icons.turn_right),
                      const SizedBox(width: 10),
                      const Text("Turn "),
                      IntrinsicWidth(
                        child: Form(
                          child: TextFormField(
                            style: const TextStyle(fontSize: 14),
                            initialValue:
                                widget.instruction.turnDegree.toString(),
                            onChanged: (String? value) {
                              if (value == null || value.isEmpty) return;
                              final tried = double.tryParse(value);
                              if (tried == null) return;
                              widget.instruction.turnDegree = tried;
                              widget.textChanged(widget.instruction);
                            },
                            inputFormatters: inputFormatters,
                          ),
                        ),
                      ),
                      const Text("° to the "),
                      DropdownMenu(
                        textStyle: const TextStyle(fontSize: 14),
                        width: 100,
                        inputDecorationTheme: const InputDecorationTheme(),
                        initialSelection: widget.instruction.left,
                        onSelected: (bool? value) {
                          setState(() => widget.instruction.left = value!);
                          widget.textChanged(widget.instruction);
                        },
                        dropdownMenuEntries: const [
                          DropdownMenuEntry(value: true, label: "left"),
                          DropdownMenuEntry(value: false, label: "right"),
                        ],
                      ),
                      const Text("with a "),
                      IntrinsicWidth(
                        child: Form(
                          child: TextFormField(
                            style: const TextStyle(fontSize: 14),
                            initialValue: "${widget.instruction.radius * 100}",
                            onChanged: (String? value) {
                              if (value == null || value.isEmpty) return;
                              final tried = double.tryParse(value);
                              if (tried == null) return;
                              widget.instruction.radius = tried / 100;
                              widget.textChanged(widget.instruction);
                            },
                            inputFormatters: inputFormatters,
                          ),
                        ),
                      ),
                      const Text("cm inner radius")
                    ],
                  ),
                ),
                IconButton(
                    onPressed: widget.removed, icon: const Icon(Icons.delete)),
              ],
            ),
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
}
