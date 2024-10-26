import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robi_line_drawer/editor/add_instruction_dialog.dart';
import 'package:robi_line_drawer/editor/bluetooth/connect_widget.dart';
import 'package:robi_line_drawer/editor/instructions/abstract.dart';
import 'package:robi_line_drawer/editor/instructions/rapid_turn.dart';
import 'package:robi_line_drawer/editor/ir_line_approximation/approximation_settings_widget.dart';
import 'package:robi_line_drawer/editor/ir_line_approximation/ir_reading_info.dart';
import 'package:robi_line_drawer/editor/painters/ir_read_painter.dart';
import 'package:robi_line_drawer/editor/visualizer.dart';
import 'package:robi_line_drawer/file_browser.dart';
import 'package:robi_line_drawer/main.dart';
import 'package:robi_line_drawer/robi_api/ir_read_api.dart';
import 'package:robi_line_drawer/robi_api/robi_utils.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

import '../app_storage.dart';
import '../robi_api/exporter/exporter.dart';
import '../robi_api/robi_path_serializer.dart';
import '../robi_api/simulator.dart';
import 'instructions/drive.dart';
import 'instructions/turn.dart';
import 'ir_line_approximation/path_to_instructions.dart';

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
  RobiConfig selectedRobiConfig = defaultRobiConfig;

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
  IrReadPainterSettings irReadPainterSettings = defaultIrReadPainterSettings();
  IrCalculator? irCalculator;
  int irInclusionThreshold = 100;

  IrReadResult? irReadResult;

  static bool readBluetoothValues = true;

  @override
  void initState() {
    super.initState();
    bleConnectionChange["editor"] = (deviceId, connected) async {
      readBluetoothValues = true;
      if (!connected) {
        readBluetoothValues = false;
        return;
      }

      while (readBluetoothValues) {
        late final Uint8List data;
        try {
          data = await UniversalBle.readValue(deviceId, serviceUuid, "00005678-0000-1000-8000-00805f9b34fb");
        } on Exception {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        irReadResult ??= const IrReadResult(resolution: 0.1, measurements: []);

        setState(() {
          irReadResult = IrReadResult(resolution: irReadResult!.resolution, measurements: [
            ...irReadResult!.measurements,
            Measurement.fromLine(data.buffer.asByteData()),
          ]);
        });

        irCalculator = IrCalculator(irReadResult: irReadResult!);
        setState(() {
          irCalculatorResult = irCalculator!.calculate(selectedRobiConfig);
          approximateIrPath();
        });
      }
    };
  }

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
                          irCalculatorResult = irCalculator!.calculate(selectedRobiConfig);
                          approximateIrPath();
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
                        Scaffold(
                          body: ListView(
                            children: [
                              IrPathApproximationSettingsWidget(
                                onPathCreation: irPathApproximation == null
                                    ? null
                                    : () {
                                        setState(() => instructions = PathToInstructions.calculate(irPathApproximation!));
                                        rerunSimulationAndUpdate();
                                      },
                                onSettingsChange: (
                                  settings,
                                  irInclusionThreshold,
                                  ramerDouglasPeuckerTolerance,
                                ) {
                                  setState(() {
                                    irReadPainterSettings = settings;
                                    this.irInclusionThreshold = irInclusionThreshold;
                                    this.ramerDouglasPeuckerTolerance = ramerDouglasPeuckerTolerance;
                                    if (irCalculatorResult != null) approximateIrPath();
                                  });
                                },
                              ),
                              if (irReadResult == null || irCalculatorResult == null) ...[
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
                                        irReadResult = IrReadResult.fromFile(file);
                                        irCalculator = IrCalculator(irReadResult: irReadResult!);
                                        irCalculatorResult = irCalculator!.calculate(selectedRobiConfig);
                                        approximateIrPath();
                                      });
                                    },
                                    icon: const Icon(Icons.file_download_outlined),
                                    label: const Text("Import IR Reading"),
                                  ),
                                ),
                              ] else ...[
                                IrReadingInfoWidget(
                                  irReadResult: irReadResult!,
                                  irCalculatorResult: irCalculatorResult!,
                                  onRemoveClick: () => setState(() {
                                    irCalculatorResult = null;
                                    irReadResult = null;
                                  }),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const BluetoothConnectWidget(),
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
    irPathApproximation = IrCalculator.pathApproximation(
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
