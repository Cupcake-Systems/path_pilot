import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grouped_list/grouped_list.dart';
import 'package:path_pilot/backend_api/submit_log.dart';
import 'package:path_pilot/helper/dialogs.dart';
import 'package:path_pilot/logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';

class LogViewer extends StatefulWidget {
  final LogFile logFile;
  static final DateFormat timeFormat = DateFormat("HH:mm:ss");

  const LogViewer({super.key, required this.logFile});

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  bool isSubmitting = false;
  static const listenerKey = "LogViewer";

  @override
  void initState() {
    super.initState();
    widget.logFile.registerListener(listenerKey, (op) => setState(() {}));
  }

  @override
  void dispose() {
    widget.logFile.unregisterListener(listenerKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("App Log"),
        actions: [
          StatefulBuilder(builder: (context, setState1) {
            return PopupMenuButton(
              itemBuilder: (context) {
                return [
                  PopupMenuItem(
                    enabled: !isSubmitting,
                    onTap: () async {
                      if (isSubmitting) {
                        showSnackBar("Already sending log");
                        return;
                      }

                      final conf = await confirmDialog(context, "Send Log", "Are you sure you want to send the log to the developers?");
                      if (!conf) return;

                      logger.info("User requested to send log");

                      setState1(() => isSubmitting = true);
                      final success = await submitLog(widget.logFile);
                      setState1(() => isSubmitting = false);

                      showSnackBar(success ? "Log sent successfully" : "Failed to send log");
                    },
                    child: const ListTile(
                      leading: Icon(Icons.send),
                      title: Text("Send log"),
                    ),
                  ),
                  if (!Platform.isAndroid)
                    PopupMenuItem(
                      child: const ListTile(
                        leading: Icon(Icons.open_in_browser),
                        title: Text("Open log file"),
                      ),
                      onTap: () async {
                        final fileUri = Uri.file(widget.logFile.file.path);

                        bool success = false;

                        try {
                          success = await launchUrl(
                            fileUri,
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (e, s) {
                          logger.errorWithStackTrace("Failed to open log file", e, s);
                        }

                        if (!success) showSnackBar("Failed to open log file");
                      },
                    ),
                  PopupMenuItem(
                    child: const ListTile(
                      leading: Icon(Icons.delete),
                      title: Text("Clear log file"),
                    ),
                    onTap: () async {
                      final conf = await confirmDialog(context, "Delete Log", "Are you sure you want to clear the log file?");
                      if (!conf) return;

                      setState(() => widget.logFile.clear());
                      if (context.mounted) {
                        showSnackBar("Log file cleared");
                      }
                    },
                  ),
                ];
              },
            );
          }),
        ],
      ),
      body: FutureBuilder(
        future: widget.logFile.read(),
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

          if (lines.isEmpty) {
            return const Center(child: Text("No log entries"));
          }

          return GroupedListView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            elements: lines,
            groupBy: (line) => line.date,
            groupHeaderBuilder: (msg) => ListTile(title: Text(msg.date)),
            itemComparator: (a, b) => a.time.compareTo(b.time),
            useStickyGroupSeparators: true,
            stickyHeaderBackgroundColor: const Color(0xFF202020),
            order: GroupedListOrder.DESC,
            itemBuilder: (context, line) {
              bool isExpanded = false;
              return StatefulBuilder(
                builder: (context, setState1) {
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    color: line.level.color,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Icon(line.level.icon, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState1(() => isExpanded = !isExpanded),
                              child: Text(
                                "${LogViewer.timeFormat.format(line.time)} - ${line.message}",
                                style: const TextStyle(fontFamily: "RobotoMono"),
                                maxLines: isExpanded ? null : 3,
                                overflow: isExpanded ? TextOverflow.visible : TextOverflow.fade,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: line.message));
                              showSnackBar("Copied to clipboard");
                            },
                            icon: const Icon(Icons.copy, size: 18),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}
