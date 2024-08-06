import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robi_line_drawer/editor/add_instruction_dialog.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';
import 'package:robi_line_drawer/editor/instructions/accelerate_over_distance.dart';
import 'package:robi_line_drawer/editor/instructions/decelerate_over_distance.dart';
import 'package:robi_line_drawer/editor/instructions/decelerate_over_time.dart';
import 'package:robi_line_drawer/editor/instructions/drive_distance.dart';
import 'package:robi_line_drawer/editor/instructions/drive_time.dart';
import 'package:robi_line_drawer/editor/instructions/rapid_turn.dart';
import 'package:robi_line_drawer/editor/painters/ir_read_painter.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:robi_line_drawer/editor/visualizer.dart';
import 'package:vector_math/vector_math.dart';

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
  late List<MissionInstruction> instructions = widget.instructions;
  double scale = 200;
  double ramerDouglasPeuckerTolerance = 0.5;
  late Simulator simulator = Simulator(widget.robiConfig);
  late SimulationResult simulationResult;

  IrReadPainterSettings irReadPainterSettings = IrReadPainterSettings(
    irReadingsThreshold: 1024,
    showCalculatedPath: true,
    showTracks: false,
  );
  InstructionResult? highlightedInstruction;
  IrCalculatorResult? irCalculatorResult;
  List<Vector2>? irPathApproximation;
  IrCalculator? irCalculator;

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
            irReadPainterSettings: irReadPainterSettings,
            highlightedInstruction: highlightedInstruction,
            irCalculatorResult: irCalculatorResult,
            irPathApproximation: irPathApproximation,
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
                Flexible(
                  flex: 5,
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
                                            instructions.length, instruction);
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
                                  rerunSimulationAndUpdate();
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    itemBuilder: (context, i) => instructionToEditor(i),
                    onReorder: (int oldIndex, int newIndex) {
                      if (oldIndex < newIndex) --newIndex;
                      instructions.insert(
                          newIndex, instructions.removeAt(oldIndex));
                      rerunSimulationAndUpdate();
                    },
                  ),
                ),
                if (irCalculatorResult != null) ...[
                  const Divider(),
                  AppBar(
                    title: const Text("IR Readings Settings"),
                    actions: [
                      IconButton(
                        onPressed: () =>
                            setState(() => irCalculatorResult = null),
                        icon: const Icon(Icons.delete),
                      )
                    ],
                  ),
                  const Divider(),
                  Flexible(
                      child: ListView(
                    children: [
                      CheckboxListTile(
                        value: irReadPainterSettings.showTracks,
                        onChanged: (value) => setState(
                            () => irReadPainterSettings.showTracks = value!),
                        title: const Text("Show Wheel Track"),
                      ),
                      ListTile(
                        title: Row(
                          children: [
                            Text(
                                "Show only IR Readings < ${irReadPainterSettings.irReadingsThreshold}"),
                            Slider(
                              value: irReadPainterSettings.irReadingsThreshold
                                  .toDouble(),
                              onChanged: (value) {
                                setState(() {
                                  irReadPainterSettings.irReadingsThreshold =
                                      value.round();
                                });
                              },
                              min: 0,
                              max: 1024,
                            )
                          ],
                        ),
                      ),
                      CheckboxListTile(
                        value: irReadPainterSettings.showCalculatedPath,
                        onChanged: (value) => setState(() =>
                            irReadPainterSettings.showCalculatedPath = value!),
                        title: const Text("Show Calculated Path"),
                      ),
                      ListTile(
                        title: Row(
                          children: [
                            const Text("Ramer Douglas Peucker Tolerance"),
                            Slider(
                              value: ramerDouglasPeuckerTolerance,
                              onChanged: (value) => setState(() {
                                ramerDouglasPeuckerTolerance = value;
                                irPathApproximation =
                                    irCalculator!.pathApproximation(
                                  irCalculatorResult!,
                                  100,
                                  ramerDouglasPeuckerTolerance,
                                );
                              }),
                              max: 5,
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            instructions.clear();
                            rerunSimulationAndUpdate();
                          });
                        },
                        child: const Text("To Path"),
                      )
                    ],
                  )),
                ],
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ["txt"],
                        );
                        if (result == null) return;
                        final file = File(result.files.single.path!);
                        final importedIrReadResult =
                            IrReadResult.fromFile(file);
                        irCalculator = IrCalculator(
                            irReadResult: importedIrReadResult,
                            robiConfig: widget.robiConfig);
                        setState(() {
                          irCalculatorResult = irCalculator!.calculate();
                          irPathApproximation = irCalculator!.pathApproximation(
                            irCalculatorResult!,
                            100,
                            ramerDouglasPeuckerTolerance,
                          );
                        });
                      },
                      icon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Text("Import Ir Reading"),
                            Icon(Icons.chevron_right)
                          ],
                        ),
                      ),
                    ),
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

  void enteredCallback(InstructionResult instructionResult) {
    setState(() {
      highlightedInstruction = instructionResult;
    });
  }

  void exitedCallback() {
    setState(() {
      highlightedInstruction = null;
    });
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
          key: ObjectKey(instruction),
          instruction: instruction,
          change: changeCallback,
          exited: exitedCallback,
          entered: enteredCallback,
          removed: removedCallback,
          simulationResult: simulationResult,
          instructionIndex: i,
        );
      } else {
        return DecelerateOverDistanceEditor(
          key: ObjectKey(instruction),
          instruction: instruction,
          simulationResult: simulationResult,
          instructionIndex: i,
          change: changeCallback,
          removed: removedCallback,
          exited: exitedCallback,
          entered: enteredCallback,
        );
      }
    } else if (instruction is AccelerateOverTimeInstruction) {
      if (instruction.acceleration > 0) {
        return AccelerateOverTimeEditor(
          key: ObjectKey(instruction),
          instruction: instruction,
          change: changeCallback,
          removed: removedCallback,
          simulationResult: simulationResult,
          instructionIndex: i,
          exited: exitedCallback,
          entered: enteredCallback,
        );
      } else {
        return DecelerateOverTimeEditor(
          key: ObjectKey(instruction),
          instruction: instruction,
          simulationResult: simulationResult,
          instructionIndex: i,
          change: changeCallback,
          removed: removedCallback,
          exited: exitedCallback,
          entered: enteredCallback,
        );
      }
    } else if (instruction is DriveInstruction) {
      return DriveInstructionEditor(
        key: ObjectKey(instruction),
        instruction: instruction,
        change: changeCallback,
        removed: removedCallback,
        simulationResult: simulationResult,
        instructionIndex: i,
        exited: exitedCallback,
        entered: enteredCallback,
      );
    } else if (instruction is TurnInstruction) {
      return TurnInstructionEditor(
        key: ObjectKey(instruction),
        instruction: instruction,
        change: changeCallback,
        removed: removedCallback,
        simulationResult: simulationResult,
        instructionIndex: i,
        robiConfig: widget.robiConfig,
        exited: exitedCallback,
        entered: enteredCallback,
      );
    } else if (instruction is RapidTurnInstruction) {
      return RapidTurnInstructionEditor(
        key: ObjectKey(instruction),
        instruction: instruction,
        change: changeCallback,
        removed: removedCallback,
        simulationResult: simulationResult,
        instructionIndex: i,
        robiConfig: widget.robiConfig,
        exited: exitedCallback,
        entered: enteredCallback,
      );
    } else if (instruction is DriveForwardDistanceInstruction) {
      return DriveDistanceEditor(
        key: ObjectKey(instruction),
        instruction: instruction,
        simulationResult: simulationResult,
        instructionIndex: i,
        change: changeCallback,
        removed: removedCallback,
        exited: exitedCallback,
        entered: enteredCallback,
      );
    } else if (instruction is DriveForwardTimeInstruction) {
      return DriveTimeEditor(
        key: ObjectKey(instruction),
        instruction: instruction,
        simulationResult: simulationResult,
        instructionIndex: i,
        change: changeCallback,
        removed: removedCallback,
        exited: exitedCallback,
        entered: enteredCallback,
      );
    }
    throw UnsupportedError("");
  }

  void rerunSimulationAndUpdate() {
    for (int i = 0; i < instructions.length; ++i) {
      final simResult = simulator.calculate(instructions.sublist(0, i));

      InstructionResult prevInstResult =
          simResult.instructionResults.lastOrNull ?? startResult;

      final instruction = instructions[i];

      if (i > 0) {
        instructions[i - 1].endVelocity = instruction.targetVelocity;
      }

      if (i == instructions.length - 1) {
        instruction.endVelocity = 0;
      }
    }

    setState(() {
      simulationResult = simulator.calculate(instructions);
    });

    widget.instructionsChanged(instructions);
  }
}

double roundToDigits(double num, int digits) {
  final e = pow(10, digits);
  return (num * e).roundToDouble() / e;
}
