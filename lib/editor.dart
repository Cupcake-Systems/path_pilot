import 'package:flutter/material.dart';
import 'package:robi_line_drawer/visualizer.dart';

abstract class MissionInstruction {}

class DriveInstruction extends MissionInstruction {
  double distance, targetVelocity, acceleration;

  DriveInstruction(this.distance, this.targetVelocity, this.acceleration);
}

class TurnInstruction extends MissionInstruction {
  double turnDegree;
  bool left;

  TurnInstruction(this.turnDegree, this.left);
}

enum AvailableInstruction { driveInstruction, turnInstruction }

class Editor extends StatefulWidget {
  const Editor({super.key});

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  List<MissionInstruction> instructions = [];
  EventListener listener = EventListener();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: Visualizer(listener: listener)),
        const VerticalDivider(width: 0),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: instructions.length,
                    itemBuilder: (context, i) {
                      final instruction = instructions[i];

                      if (instruction is DriveInstruction) {
                        return DriveInstructionEditor(
                          key: Key(i.toString()),
                          instruction: instruction,
                          textChanged: (newInstruction) {
                            instructions[i] = newInstruction;
                            listener.fireEvent(instructions);
                          },
                          removed: () {
                            instructions.removeAt(i);
                            setState(() {});
                          },
                        );
                      }

                      if (instruction is TurnInstruction) {
                        return TurnInstructionEditor(
                          key: Key(i.toString()),
                          instruction: instruction,
                          textChanged: (newInstruction) {
                            instructions[i] = newInstruction;
                            listener.fireEvent(instructions);
                          },
                          removed: () {
                            instructions.removeAt(i);
                            setState(() {});
                          },
                        );
                      }

                      throw UnsupportedError("");
                    },
                    onReorder: (int oldIndex, int newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = instructions.removeAt(oldIndex);
                        instructions.insert(newIndex, item);
                      });
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add),
                      onPressed: () => showDialog<AvailableInstruction?>(
                        context: context,
                        builder: (BuildContext context) {
                          AvailableInstruction selectedInstruction =
                              AvailableInstruction.driveInstruction;
                          return StatefulBuilder(builder: (context, setState) {
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
                                    value: AvailableInstruction.turnInstruction,
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
                    ElevatedButton(
                      onPressed: () => setState(instructions.clear),
                      child: const Text("Clear"),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void addInstruction(AvailableInstruction instruction) {
    switch (instruction) {
      case AvailableInstruction.driveInstruction:
        instructions.add(DriveInstruction(1, 0.5, 0.3));
        break;
      case AvailableInstruction.turnInstruction:
        instructions.add(TurnInstruction(90, false));
        break;
    }
    setState(() {});
    listener.fireEvent(instructions);
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

  final Function(DriveInstruction newInstruction) textChanged;
  final Function() removed;

  late final TextEditingController distanceController =
      TextEditingController(text: instruction.distance.toString());
  late final TextEditingController velocityController =
      TextEditingController(text: instruction.targetVelocity.toString());
  late final TextEditingController accelerationController =
      TextEditingController(text: instruction.acceleration.toString());

  DriveInstructionEditor(
      {super.key,
      required this.instruction,
      required this.textChanged,
      required this.removed});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.only(left: 10, right: 40, top: 10, bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_upward),
                  const SizedBox(width: 10),
                  const Text("Drive "),
                  Flexible(
                    child: createTextField(
                      distanceController,
                      "Distance",
                      (value) => instruction.distance = value,
                      () => instruction.distance,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text("m with a targeted velocity of "),
                  Flexible(
                    child: createTextField(
                      velocityController,
                      "Target Velocity",
                      (value) => instruction.targetVelocity = value,
                      () => instruction.targetVelocity,
                    ),
                  ),
                  const Text(" m/s accelerating at"),
                  const SizedBox(width: 10),
                  Flexible(
                    child: createTextField(
                        accelerationController,
                        "Acceleration",
                        (value) => instruction.acceleration = value,
                        () => instruction.acceleration),
                  ),
                  const Text(" m/s²"),
                ],
              ),
            ),
            IconButton(onPressed: removed, icon: const Icon(Icons.delete))
          ],
        ),
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

  final Function() removed;
  final Function(TurnInstruction newInstruction) textChanged;

  const TurnInstructionEditor(
      {super.key,
      required this.instruction,
      required this.textChanged,
      required this.removed});

  @override
  State<TurnInstructionEditor> createState() => _TurnInstructionEditorState();
}

class _TurnInstructionEditorState extends State<TurnInstructionEditor> {
  late final TextEditingController rotation =
      TextEditingController(text: widget.instruction.turnDegree.toString());

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.only(left: 10, right: 40, top: 10, bottom: 10),
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
                  Flexible(
                    child: Builder(builder: (context) {
                      final controller = TextEditingController(
                          text: widget.instruction.turnDegree.toString());
                      return TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: "Degree"),
                        onChanged: (String? value) {
                          final res = asdf(controller, value);
                          if (res == null) {
                            controller.text =
                                widget.instruction.turnDegree.toString();
                            return;
                          }
                          widget.instruction.turnDegree = res;
                          widget.textChanged(widget.instruction);
                        },
                      );
                    }),
                  ),
                  const Text("° to the "),
                  Flexible(
                    child: DropdownMenu(
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
                  ),
                ],
              ),
            ),
            IconButton(
                onPressed: widget.removed, icon: const Icon(Icons.delete)),
          ],
        ),
      ),
    );
  }
}
