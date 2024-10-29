import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  final Function() newFilePressed;
  final Function() openFilePressed;
  final String? errorMessage;

  const WelcomeScreen({
    super.key,
    required this.newFilePressed,
    required this.openFilePressed,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              style: const ButtonStyle(
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
                  ),
                ),
              ),
              icon: const Icon(Icons.add),
              onPressed: newFilePressed,
              label: const Text('Create'),
            ),
            const SizedBox(
              height: 30,
              child: VerticalDivider(width: 1),
            ),
            ElevatedButton.icon(
              style: const ButtonStyle(
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
                  ),
                ),
              ),
              icon: const Icon(Icons.folder),
              onPressed: openFilePressed,
              label: const Text('Open'),
            ),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 10),
          Card(
            surfaceTintColor: Colors.red,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ]
      ],
    );
  }
}
