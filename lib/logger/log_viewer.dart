import 'package:flutter/material.dart';
import 'package:path_pilot/logger/logger.dart';

class LogViewer extends StatelessWidget {
  final LogFile logFile;

  const LogViewer({super.key, required this.logFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Viewer"),
      ),
      body: FutureBuilder(
        future: logFile.read(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final lines = snapshot.data;

          if (lines == null) {
            return const Center(child: Text("No data"));
          }

          return ListView.builder(
            itemCount: lines.length,
            itemBuilder: (context, index) {
              final line = lines[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: Icon(line.level.icon),
                  title: Text("${line.formattedTime} - ${line.message}"),
                  tileColor: line.level.color,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
