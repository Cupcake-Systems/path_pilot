import 'package:flutter/material.dart';
import 'package:grouped_list/grouped_list.dart';
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

          return GroupedListView(
            elements: lines,
            groupBy: (line) => line.date,
            groupHeaderBuilder: (msg) => ListTile(title: Text(msg.date)),
            itemComparator: (a, b) => a.time.compareTo(b.time),
            useStickyGroupSeparators: true,
            stickyHeaderBackgroundColor: const Color(0xFF202020),
            order: GroupedListOrder.DESC,
            itemBuilder: (context, line) {
              return Card(
                clipBehavior: Clip.antiAlias,
                color: line.level.color,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(line.level.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "${line.formattedTime} - ${line.message}",
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
