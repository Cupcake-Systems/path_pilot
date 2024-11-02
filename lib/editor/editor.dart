import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robi_line_drawer/editor/add_instruction_dialog.dart';
import 'package:robi_line_drawer/editor/bluetooth/bluetooth_visualizer.dart';
import 'package:robi_line_drawer/editor/bluetooth/connect_widget.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';
import 'package:robi_line_drawer/editor/instructions/rapid_turn.dart';
import 'package:robi_line_drawer/editor/visualizer.dart';
import 'package:robi_line_drawer/file_browser.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';

import '../app_storage.dart';
import '../robi_api/exporter/exporter.dart';
import '../robi_api/robi_path_serializer.dart';
import '../robi_api/simulator.dart';
import 'instructions/drive.dart';
import 'instructions/turn.dart';
import 'ir_line_approximation/path_to_instructions.dart';
import 'ir_visualizer.dart';

final inputFormatters = [FilteringTextInputFormatter.allow(RegExp(r'^(\d+)?\.?\d{0,5}'))];

class Editor extends StatefulWidget {
  final List<MissionInstruction> initialInstructions;
  final File file;

  const Editor({
    super.key,
    required this.initialInstructions,
    required this.file,
  });

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> with AutomaticKeepAliveClientMixin {
  RobiConfig selectedRobiConfig = defaultRobiConfig;

  late List<MissionInstruction> instructions = List.from(widget.initialInstructions);
  late Simulator simulator = Simulator(selectedRobiConfig);

  // Visualizer
  double zoom = 10;
  Offset offset = Offset.zero;
  bool lockToRobi = false;
  InstructionResult? highlightedInstruction;
  late SimulationResult simulationResult = simulator.calculate(instructions);

  // IR Visualizer
  List<IrReadResult> irReadResults = [];

  // Developer Options
  int randomInstructionsGenerationLength = 100;
  Duration? randomInstructionsGenerationDuration;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Row(
      children: [
        Flexible(
          child: InstructionsVisualizer(
            simulationResult: simulationResult,
            totalTime: simulationResult.totalTime,
            getStateAtTime: (t) => simulationResult.getStateAtTime(t),
            key: ValueKey(simulationResult),
            scale: zoom,
            offset: offset,
            lockToRobi: lockToRobi,
            transformChanged: (newZoom, newOffset, newLockToRobi) {
              offset = newOffset;
              zoom = newZoom;
              lockToRobi = newLockToRobi;
            },
            robiConfig: selectedRobiConfig,
            highlightedInstruction: highlightedInstruction,
          ),
        ),
        const VerticalDivider(width: 1),
        Flexible(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Text("Robi Config: "),
                    DropdownMenu(
                      inputDecorationTheme: const InputDecorationTheme(),
                      textStyle: const TextStyle(fontSize: 14),
                      menuStyle: const MenuStyle(),
                      dropdownMenuEntries: [defaultRobiConfig, ...RobiConfigStorage.configs]
                          .map(
                            (config) => DropdownMenuEntry(value: config, label: config.name),
                          )
                          .toList(),
                      initialSelection: selectedRobiConfig,
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedRobiConfig = value;
                          rerunSimulationAndUpdate();
                          //irCalculatorResult = irCalculator!.calculate(selectedRobiConfig);
                          //approximateIrPath();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: DefaultTabController(
                  length: 3,
                  child: Scaffold(
                    appBar: PreferredSize(
                      preferredSize: const Size.fromHeight(32),
                      child: AppBar(
                        flexibleSpace: const TabBar(
                          tabs: [
                            Tab(child: Text("Instructions")),
                            Tab(child: Text("IR Readings")),
                            Tab(child: Text("IR Bluetooth")),
                          ],
                        ),
                      ),
                    ),
                    body: TabBarView(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MenuBar(
                              clipBehavior: Clip.antiAlias,
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
                                  onPressed: () async {
                                    await RobiPathSerializer.saveToFile(widget.file, instructions);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Saved')),
                                    );
                                  },
                                  child: const MenuAcceleratorLabel('&Save'),
                                ),
                                const VerticalDivider(width: 0),
                                MenuItemButton(
                                  onPressed: simulationResult.instructionResults.isEmpty ? null : exportClick,
                                  trailingIcon: const Icon(Icons.file_upload_outlined),
                                  child: const MenuAcceleratorLabel("&Export"),
                                ),
                              ],
                            ),
                            Expanded(
                              child: ReorderableListView.builder(
                                header: const SizedBox(height: 3),
                                itemCount: instructions.length,
                                itemBuilder: (context, i) => instructionToEditor(i),
                                onReorder: (int oldIndex, int newIndex) {
                                  if (oldIndex < newIndex) --newIndex;
                                  instructions.insert(newIndex, instructions.removeAt(oldIndex));
                                  rerunSimulationAndUpdate();
                                },
                              ),
                            ),
                            Column(
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
                                if (SettingsStorage.developerMode)
                                  Card.outlined(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Row(
                                        children: [
                                          const Text("Generate Random Instructions"),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: TextFormField(
                                              initialValue: randomInstructionsGenerationLength.toString(),
                                              onChanged: (value) {
                                                final parsed = int.tryParse(value);
                                                if (parsed == null) return;
                                                randomInstructionsGenerationLength = parsed;
                                              },
                                              decoration: const InputDecoration(labelText: "Generation Length"),
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          if (randomInstructionsGenerationDuration != null) Text("(took ${randomInstructionsGenerationDuration!.inMilliseconds}ms)"),
                                          const SizedBox(width: 10),
                                          IconButton(
                                            onPressed: () {
                                              for (int i = 0; i < randomInstructionsGenerationLength; i++) {
                                                instructions.add(MissionInstruction.generateRandom());
                                              }
                                              final sw = Stopwatch()..start();
                                              rerunSimulationAndUpdate();
                                              sw.stop();
                                              setState(() {
                                                randomInstructionsGenerationDuration = sw.elapsed;
                                              });
                                            },
                                            icon: const Icon(Icons.send),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        Scaffold(
                          body: ListView(
                            children: [
                              for (final irReadResult in irReadResults) ...[
                                Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      IrVisualizerWidget(
                                        robiConfig: selectedRobiConfig,
                                        onPathCreationClick: (pathApproximation) {
                                          setState(() => instructions = PathToInstructions.calculate(pathApproximation));
                                          rerunSimulationAndUpdate();
                                        },
                                        irReadResult: irReadResult,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              irReadResults.remove(irReadResult);
                                            });
                                          },
                                          icon: const Icon(Icons.remove),
                                          label: const Text("Remove IR Reading"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ["bin"],
                                    );
                                    if (result == null) return;
                                    final file = File(result.files.single.path!);
                                    setState(() {
                                      irReadResults.add(IrReadResult.fromFile(file));
                                    });
                                  },
                                  icon: const Icon(Icons.file_download_outlined),
                                  label: const Text("Import IR Reading"),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              const BluetoothConnectWidget(),
                              BluetoothVisualizerWidget(
                                robiConfig: selectedRobiConfig,
                                onPathCreationClick: (pathApproximation) {},
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
      selectedRobiConfig,
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
    InstructionResult? currentResult;

    for (int i = 0; i < instructions.length - 1; ++i) {
      final instruction = instructions[i];
      final nextInstruction = instructions[i + 1];

      if (nextInstruction is RapidTurnInstruction) {
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

      if (currentResult != null) {
        // Ensure the initial velocity for the next instruction is always <= than the target velocity
        // because an instruction cannot decelerate to target velocity, only accelerate.
        if (currentResult.finalOuterVelocity > nextInstruction.targetVelocity) {
          instruction.acceleration = 1; // TODO: Calculate the value
        }
      }

      currentResult = simulator.simulateInstruction(currentResult, instruction);
    }

    // Always decelerate to stop at end
    instructions.lastOrNull?.targetFinalVelocity = 0;

    setState(() {
      simulationResult = simulator.calculate(instructions);
    });
  }

  @override
  bool get wantKeepAlive => true;
}

double roundToDigits(double num, int digits) {
  final e = pow(10, digits);
  return (num * e).roundToDouble() / e;
}
