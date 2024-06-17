import 'package:flutter/material.dart';

import '../robi_api/robi_path_serializer.dart';
import '../robi_api/robi_utils.dart';
import 'editor.dart';

class AddInstructionDialog extends StatefulWidget {
  final Function(MissionInstruction instruction) instructionAdded;
  final SimulationResult simulationResult;

  const AddInstructionDialog({
    super.key,
    required this.instructionAdded,
    required this.simulationResult,
  });

  @override
  State<AddInstructionDialog> createState() => _AddInstructionDialogState();
}

class _AddInstructionDialogState extends State<AddInstructionDialog> {
  UserInstruction selectedInstruction = UserInstruction.drive;

  RadioListTile createRadioButtonForAdd(UserInstruction value) {
    final IconData? icon = userInstructionToIcon[value];
    return RadioListTile<UserInstruction>(
      title: ListTile(
        title: Text(camelToSentence(value.name)),
        leading: Icon(icon),
      ),
      value: value,
      groupValue: selectedInstruction,
      onChanged: (v) => setState(() => selectedInstruction = v!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Instruction"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final groupName in groupedUserInstructions.keys) ...[
            Text(groupName, style: const TextStyle(fontSize: 20)),
            for (final userInstruction in groupedUserInstructions[groupName]!)...[
              createRadioButtonForAdd(userInstruction),
            ],
            const Divider(height: 5),
          ]
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
                widget.simulationResult.instructionResults.lastOrNull ??
                    startResult,
                widget.simulationResult.instructionResults.lastWhere(
                    (e) => e is DriveResult,
                    orElse: () => startResult) as DriveResult);
          },
          child: const Text("Ok"),
        ),
      ],
    );
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
      case UserInstruction.decelerateOverTime:
        inst = AccelerateOverTimeInstruction(
            prevInstResult.managedVelocity, 1, -0.3);
        break;
    }

    widget.instructionAdded(inst);
  }
}

enum UserInstruction {
  drive,
  turn,
  accelerateOverDistance,
  decelerateOverDistance,
  accelerateOverTime,
  decelerateOverTime,
  driveDistance,
  driveTime,
}

const Map<String, List<UserInstruction>> groupedUserInstructions = {
  "Basic": [UserInstruction.drive, UserInstruction.turn],
  "Drive": [UserInstruction.driveDistance, UserInstruction.driveTime],
  "Accelerate": [
    UserInstruction.accelerateOverDistance,
    UserInstruction.accelerateOverTime
  ],
  "Decelerate": [
    UserInstruction.decelerateOverDistance,
    UserInstruction.decelerateOverTime
  ],
};

const Map<UserInstruction, IconData> userInstructionToIcon = {
  UserInstruction.drive: Icons.arrow_upward,
  UserInstruction.turn: Icons.turn_right,
  UserInstruction.accelerateOverDistance: Icons.speed,
  UserInstruction.accelerateOverTime: Icons.speed,
  UserInstruction.driveDistance: Icons.arrow_upward,
  UserInstruction.driveTime: Icons.arrow_upward,
  UserInstruction.decelerateOverDistance: Icons.speed,
  UserInstruction.decelerateOverTime: Icons.speed,
};

String camelToSentence(String text) => text.replaceAllMapped(
    RegExp(r'^([a-z])|[A-Z]'),
    (Match m) => m[1] == null ? " ${m[0]}" : m[1]!.toUpperCase());
