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
import 'package:robi_line_drawer/editor/robi_config.dart';
import 'package:robi_line_drawer/editor/visualizer.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../app_storage.dart';
import '../robi_api/exporter/exporter.dart';
import '../robi_api/robi_path_serializer.dart';
import '../robi_api/simulator.dart';
import 'instructions/drive.dart';
import 'instructions/turn.dart';

final inputFormatters = [FilteringTextInputFormatter.allow(RegExp(r'^(\d+)?\.?\d{0,5}'))];

class Editor extends StatefulWidget {
  final List<MissionInstruction> initailInstructions;
  final File file;

  const Editor({
    super.key,
    required this.initailInstructions,
    required this.file,
  });

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> with AutomaticKeepAliveClientMixin {
  RobiConfig selectedRobiConfig = RobiConfigStorage.lastUsedConfig;

  late List<MissionInstruction> instructions = List.from(widget.initailInstructions);
  late Simulator simulator = Simulator(selectedRobiConfig);

  // Visualizer
  double scale = 10;
  Offset offset = Offset.zero;
  InstructionResult? highlightedInstruction;
  IrCalculatorResult? irCalculatorResult;
  List<Vector2>? irPathApproximation;
  late SimulationResult simulationResult = simulator.calculate(instructions);

  // IR readings settings
  double ramerDouglasPeuckerTolerance = 0.5;
  IrReadPainterSettings irReadPainterSettings = IrReadPainterSettings(
    irReadingsThreshold: 1024,
    showCalculatedPath: true,
    showTracks: false,
  );
  IrCalculator? irCalculator;
  int irInclusionThreshold = 100;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            robiConfig: selectedRobiConfig,
            irReadPainterSettings: irReadPainterSettings,
            highlightedInstruction: highlightedInstruction,
            irCalculatorResult: irCalculatorResult,
            irPathApproximation: irPathApproximation,
          ),
        ),
        const VerticalDivider(width: 1),
        Flexible(
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: AppBar(
                  flexibleSpace: const TabBar(
                    tabs: [
                      Tab(child: Text("Instructions")),
                      Tab(child: Text("IR Readings")),
                    ],
                  ),
                ),
              ),
              body: TabBarView(
                children: [
                  ReorderableListView.builder(
                    itemCount: instructions.length,
                    header: Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: MenuBar(
                        clipBehavior: Clip.hardEdge,
                        style: const MenuStyle(
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        children: [
                          MenuItemButton(
                            leadingIcon: const Icon(Icons.save),
                            onPressed: () {
                              RobiPathSerializer.saveToFile(widget.file, instructions);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Saved')),
                              );
                            },
                            child: const MenuAcceleratorLabel('&Save'),
                          ),
                          const VerticalDivider(width: 0),
                          SubmenuButton(
                            menuChildren: [
                              MenuItemButton(
                                leadingIcon: const Icon(Icons.add),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => RobiConfigurator(
                                    addedConfig: (config) {
                                      RobiConfigStorage.add(config);
                                      RobiConfigStorage.lastUsedConfigIndex = RobiConfigStorage.length - 1;
                                      setState(() {
                                        selectedRobiConfig = config;
                                        rerunSimulationAndUpdate();
                                        irCalculatorResult = irCalculator!.calculate(selectedRobiConfig);
                                        approximateIrPath();
                                      });
                                    },
                                    index: RobiConfigStorage.length,
                                  ),
                                ),
                                child: const MenuAcceleratorLabel('&New'),
                              ),
                              const Divider(height: 0),
                              SubmenuButton(
                                menuChildren: [
                                  for (int i = 0; i < RobiConfigStorage.length; ++i)
                                    RadioMenuButton(
                                      trailingIcon: RobiConfigStorage.length <= 1
                                          ? null
                                          : IconButton(
                                              icon: const Icon(Icons.delete),
                                              onPressed: () {
                                                RobiConfigStorage.remove(RobiConfigStorage.get(i));
                                                RobiConfigStorage.lastUsedConfigIndex = 0;
                                                setState(() {
                                                  selectedRobiConfig = RobiConfigStorage.get(0);
                                                  rerunSimulationAndUpdate();
                                                  irCalculatorResult = irCalculator!.calculate(selectedRobiConfig);
                                                  approximateIrPath();
                                                });
                                              },
                                            ),
                                      value: RobiConfigStorage.get(i),
                                      groupValue: selectedRobiConfig,
                                      onChanged: (value) {
                                        RobiConfigStorage.lastUsedConfigIndex = RobiConfigStorage.indexOf(value!);
                                        setState(() {
                                          selectedRobiConfig = value;
                                          rerunSimulationAndUpdate();
                                          irCalculatorResult = irCalculator!.calculate(selectedRobiConfig);
                                          approximateIrPath();
                                        });
                                      },
                                      child: MenuAcceleratorLabel(RobiConfigStorage.get(i).name ?? '&Config ${i + 1}'),
                                    )
                                ],
                                child: const MenuAcceleratorLabel('&Select'),
                              ),
                            ],
                            child: const MenuAcceleratorLabel("&Robi Config"),
                          ),
                          const VerticalDivider(width: 0),
                          MenuItemButton(
                            onPressed: simulationResult.instructionResults.isEmpty ? null : exportClick,
                            trailingIcon: const Icon(Icons.file_upload_outlined),
                            child: const MenuAcceleratorLabel("&Export"),
                          ),
                        ],
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
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  icon: const Icon(Icons.add),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (BuildContext context) => AddInstructionDialog(
                                      instructionAdded: (MissionInstruction instruction) {
                                        instructions.insert(instructions.length, instruction);
                                        rerunSimulationAndUpdate();
                                      },
                                      robiConfig: selectedRobiConfig,
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
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
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
                      instructions.insert(newIndex, instructions.removeAt(oldIndex));
                      rerunSimulationAndUpdate();
                    },
                  ),
                  if (irCalculatorResult != null) ...[
                    Scaffold(
                      floatingActionButton: ElevatedButton.icon(
                        onPressed: () => setState(() => irCalculatorResult = null),
                        label: const Text("Remove"),
                        icon: const Icon(Icons.delete),
                      ),
                      body: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListView(
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
                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                children: [
                                  TableRow(
                                    children: [
                                      const Text("Show wheel track"),
                                      Checkbox(
                                        value: irReadPainterSettings.showTracks,
                                        onChanged: (value) => setState(
                                          () => irReadPainterSettings.showTracks = value!,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TableRow(
                                    children: [
                                      Text("Show only IR readings < ${irReadPainterSettings.irReadingsThreshold}"),
                                      Slider(
                                        value: irReadPainterSettings.irReadingsThreshold.toDouble(),
                                        onChanged: (value) {
                                          setState(() {
                                            irReadPainterSettings.irReadingsThreshold = value.round();
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
                                        value: irReadPainterSettings.showCalculatedPath,
                                        onChanged: (value) => setState(() => irReadPainterSettings.showCalculatedPath = value!),
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
                                      const Text("Ramer Douglas Peucker tolerance"),
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
                                      Text("IR inclusion threshold: < $irInclusionThreshold"),
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
                                          PathToInstructions c = PathToInstructions(irPathApproximation: irPathApproximation!);
                                          setState(() => instructions = c.calculate());
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
                  ] else ...[
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ["bin"],
                          );
                          if (result == null) return;
                          final file = File(result.files.single.path!);
                          final importedIrReadResult = IrReadResult.fromFile(file);
                          irCalculator = IrCalculator(irReadResult: importedIrReadResult);
                          setState(() {
                            irCalculatorResult = irCalculator!.calculate(selectedRobiConfig);
                            approximateIrPath();
                          });
                        },
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text("Import IR Reading"),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void exportClick() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: "Please select an output file:",
      fileName: "exported.json.gz",
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
        if (calcRes.instructionResults.last.finalOuterVelocity > nextInstruction.targetVelocity) {
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
  }

  void approximateIrPath() {
    irPathApproximation = irCalculator!.pathApproximation(
      irCalculatorResult!,
      irInclusionThreshold,
      ramerDouglasPeuckerTolerance,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

double roundToDigits(double num, int digits) {
  final e = pow(10, digits);
  return (num * e).roundToDouble() / e;
}
