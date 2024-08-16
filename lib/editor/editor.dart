import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robi_line_drawer/editor/add_instruction_dialog.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';
import 'package:robi_line_drawer/editor/instructions/rapid_turn.dart';
import 'package:robi_line_drawer/editor/ir_line_approximation/path_to_instructions.dart';
import 'package:robi_line_drawer/editor/painters/ir_read_painter.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:robi_line_drawer/editor/visualizer.dart';
import 'package:vector_math/vector_math.dart';

import '../app_storage.dart';
import '../robi_api/exporter/exporter.dart';
import '../robi_api/simulator.dart';
import 'instructions/drive.dart';
import 'instructions/turn.dart';

final inputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'^(\d+)?\.?\d{0,5}'))
];

class Editor extends StatefulWidget {
  final List<MissionInstruction> instructions;
  final RobiConfig robiConfig;
  final void Function(List<MissionInstruction> instructions)
      instructionsChanged;

  const Editor({
    super.key,
    required this.instructions,
    required this.robiConfig,
    required this.instructionsChanged,
  });

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  late List<MissionInstruction> instructions = widget.instructions;
  double scale = 10;
  Offset offset = Offset.zero;
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
  int irInclusionThreshold = 100;

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
            offset: offset,
            transformChanged: (newScale, newOffset) {
              offset = newOffset;
              scale = newScale;
            },
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
                Flexible(
                  flex: 2,
                  child: Scaffold(
                    appBar: AppBar(
                      title: const Text("Instructions"),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    body: ReorderableListView.builder(
                      itemCount: instructions.length,
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
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 20),
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
                                        robiConfig: widget.robiConfig,
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
                ),
                if (irCalculatorResult != null) ...[
                  const Divider(),
                  Flexible(
                    child: Scaffold(
                      appBar: AppBar(
                        title: const Text("IR Readings Settings"),
                        actions: [
                          IconButton(
                            onPressed: () =>
                                setState(() => irCalculatorResult = null),
                            icon: const Icon(Icons.delete),
                          ),
                        ],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      body: ListView(
                        children: [
                          const Text(
                            "Visibility",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1),
                                1: FlexColumnWidth(2),
                              },
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  children: [
                                    const Text("Show wheel track"),
                                    Checkbox(
                                      value: irReadPainterSettings.showTracks,
                                      onChanged: (value) => setState(
                                        () => irReadPainterSettings.showTracks =
                                            value!,
                                      ),
                                    ),
                                  ],
                                ),
                                TableRow(
                                  children: [
                                    Text(
                                        "Show only IR readings < ${irReadPainterSettings.irReadingsThreshold}"),
                                    Slider(
                                      value: irReadPainterSettings
                                          .irReadingsThreshold
                                          .toDouble(),
                                      onChanged: (value) {
                                        setState(() {
                                          irReadPainterSettings
                                                  .irReadingsThreshold =
                                              value.round();
                                        });
                                      },
                                      max: 1024,
                                      divisions: 1024,
                                    ),
                                  ],
                                ),
                                TableRow(
                                  children: [
                                    const Text("Show calculated path"),
                                    Checkbox(
                                      value: irReadPainterSettings
                                          .showCalculatedPath,
                                      onChanged: (value) => setState(() =>
                                          irReadPainterSettings
                                              .showCalculatedPath = value!),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            "Path Approximation",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1),
                                1: FlexColumnWidth(2),
                              },
                              children: [
                                TableRow(
                                  children: [
                                    const Text(
                                        "Ramer Douglas Peucker tolerance"),
                                    Slider(
                                      value: ramerDouglasPeuckerTolerance,
                                      onChanged: (value) => setState(() {
                                        ramerDouglasPeuckerTolerance = value;
                                        approximateIrPath();
                                      }),
                                      max: 5,
                                    ),
                                  ],
                                ),
                                TableRow(
                                  children: [
                                    Text(
                                        "IR inclusion threshold: < $irInclusionThreshold"),
                                    Slider(
                                      value: irInclusionThreshold.toDouble(),
                                      onChanged: (value) => setState(() {
                                        irInclusionThreshold = value.round();
                                        approximateIrPath();
                                      }),
                                      divisions: 1024,
                                      max: 1024,
                                    ),
                                  ],
                                ),
                                TableRow(
                                  children: [
                                    const Text("Convert to Path"),
                                    ElevatedButton(
                                      onPressed: () {
                                        PathToInstructions c =
                                            PathToInstructions(
                                                irPathApproximation:
                                                    irPathApproximation!);
                                        setState(
                                            () => instructions = c.calculate());
                                        rerunSimulationAndUpdate();
                                      },
                                      child: const Text("To Path"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                          approximateIrPath();
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
                          : exportClick,
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

  void exportClick() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: "Please select an output file:",
      fileName: "exported.json",
    );
    if (path == null) return;
    Exporter.saveToFile(
      File(path),
      RobiConfigStorage.lastUsedConfig,
      simulationResult.instructionResults,
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

    if (instruction is DriveInstruction) {
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
        exited: exitedCallback,
        entered: enteredCallback,
      );
    }
    throw UnsupportedError("");
  }

  void rerunSimulationAndUpdate() {
    for (int i = 0; i < instructions.length - 1; ++i) {
      final calcRes = simulator.calculate(instructions.sublist(0, i));

      final instruction = instructions[i];
      final nextInstruction = instructions[i + 1];

      if (instructions[i + 1] is RapidTurnInstruction) {
        // Always stop at end of instruction if next instruction is rapid turn.
        instruction.targetFinalVelocity = 0;
      } else {
        if (instruction.targetVelocity > nextInstruction.targetVelocity) {
          // Ensure the initial velocity for the next instruction is always <= than the target velocity.
          instruction.targetFinalVelocity = nextInstruction.targetVelocity;
        } else {
          instruction.targetFinalVelocity = instruction.targetVelocity;
        }
      }

      if (i > 0) {
        // Ensure the initial velocity for the next instruction is always <= than the target velocity
        // because an instruction cannot decelerate to target velocity, only accelerate.
        if (calcRes.instructionResults.last.finalOuterVelocity >
            nextInstruction.targetVelocity) {
          setState(() {
            instruction.acceleration = 1; // TODO: Calculate the value
          });
        }
      }
    }

    // Always decelerate to stop at end
    instructions.lastOrNull?.targetFinalVelocity = 0;

    setState(() {
      simulationResult = simulator.calculate(instructions);
    });

    widget.instructionsChanged(instructions);
  }

  void approximateIrPath() {
    irPathApproximation = irCalculator!.pathApproximation(
      irCalculatorResult!,
      irInclusionThreshold,
      ramerDouglasPeuckerTolerance,
    );
  }
}

double roundToDigits(double num, int digits) {
  final e = pow(10, digits);
  return (num * e).roundToDouble() / e;
}
