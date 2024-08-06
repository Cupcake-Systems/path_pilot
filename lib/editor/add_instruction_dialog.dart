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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final groupName in groupedUserInstructions.keys) ...[
              Text(groupName, style: const TextStyle(fontSize: 20)),
              for (final userInstruction
                  in groupedUserInstructions[groupName]!) ...[
                createRadioButtonForAdd(userInstruction),
              ],
              const Divider(height: 5),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            final inst = addInstruction(
                selectedInstruction,
                widget.simulationResult.instructionResults.lastOrNull ??
                    startResult,
                widget.simulationResult.instructionResults.lastWhere(
                    (e) => e is DriveResult,
                    orElse: () => startResult) as DriveResult);
            widget.instructionAdded(inst);
          },
          child: const Text("Ok"),
        ),
      ],
    );
  }
}

enum UserInstruction {
  drive,
  turn,
  rapidTurn,
  accelerateOverDistance,
  decelerateOverDistance,
  accelerateOverTime,
  decelerateOverTime,
  driveDistance,
  driveTime,
}

MissionInstruction addInstruction(UserInstruction instruction,
    InstructionResult prevInstResult, DriveResult lastDriveResult) {
  switch (instruction) {
    case UserInstruction.driveDistance:
      return DriveForwardDistanceInstruction(
          distance: 0.5,
          initialVelocity: prevInstResult.finalVelocity,
          endVelocity: 0);
    case UserInstruction.accelerateOverDistance:
      return AccelerateOverDistanceInstruction(
          initialVelocity: prevInstResult.finalVelocity,
          distance: 0.5,
          acceleration: 0.3,
          endVelocity: 0);
    case UserInstruction.drive:
      double targetVel = 0.5;
      double acceleration = 0.3;

      if (prevInstResult is TurnResult) {
        targetVel = lastDriveResult.finalVelocity;
      }

      if (prevInstResult.finalVelocity > targetVel) {
        acceleration = -acceleration;
      }

      return DriveInstruction(
        distance: 1,
        targetVelocity: roundToDigits(targetVel, 2),
        acceleration: acceleration,
        endVelocity: 0,
        initialVelocity: prevInstResult.finalVelocity,
      );
    case UserInstruction.turn:
      return TurnInstruction(
        turnDegree: 90,
        innerRadius: 0.05,
        targetVelocity: prevInstResult.maxVelocity,
        acceleration: 0.1,
        endVelocity: prevInstResult.maxVelocity,
        initialVelocity: prevInstResult.finalVelocity
      );
    case UserInstruction.rapidTurn:
      return RapidTurnInstruction(
        turnDegree: 90,
      );
    case UserInstruction.accelerateOverTime:
      return AccelerateOverTimeInstruction(
        initialVelocity: prevInstResult.finalVelocity,
        time: 1,
        acceleration: 0.3,
        endVelocity: 0,
      );
    case UserInstruction.driveTime:
      return DriveForwardTimeInstruction(
        time: 1,
        initialVelocity: prevInstResult.finalVelocity,
        endVelocity: 0,
      );
    case UserInstruction.decelerateOverDistance:
      return AccelerateOverDistanceInstruction(
        initialVelocity: prevInstResult.finalVelocity,
        distance: 0.5,
        acceleration: -0.3,
        endVelocity: 0,
      );
    case UserInstruction.decelerateOverTime:
      return AccelerateOverTimeInstruction(
        initialVelocity: prevInstResult.finalVelocity,
        time: 1,
        acceleration: -0.3,
        endVelocity: 0,
      );
  }
}

const Map<String, List<UserInstruction>> groupedUserInstructions = {
  "Basic": [
    UserInstruction.drive,
    UserInstruction.turn,
    UserInstruction.rapidTurn
  ],
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
  UserInstruction.rapidTurn: Icons.turn_right,
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
