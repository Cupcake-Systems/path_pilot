import 'package:flutter/material.dart';
import 'package:path_pilot/main.dart';

Future<bool> confirmDialog(BuildContext context, String title, String content) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      );
    },
  );
  return answer == true;
}

void showSnackBar(String message, {Duration duration = const Duration(seconds: 3)}) {
  snackBarKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
