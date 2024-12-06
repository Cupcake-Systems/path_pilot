import 'dart:convert';
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
  int? logEnd = 50;

  bool get autoReload => logEnd != null;

  @override
  void initState() {
    super.initState();
    widget.logFile.registerListener(listenerKey, (op) {
      if (autoReload) setState(() {});
    });
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
          if (!autoReload)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {}),
            ),
          const SizedBox(width: 8),
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
        future: widget.logFile.read(0, logEnd),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final data = snapshot.data;

          if (data == null) {
            return const Center(child: Text("No data"));
          }

          final (lines, allCount) = data;

          if (lines.isEmpty) {
            return const Center(child: Text("No log entries"));
          }

          return GroupedListViewWidget(
            lines: lines,
            loadAll: logEnd == null || logEnd! >= allCount
                ? null
                : () {
                    setState(() => logEnd = null);
                  },
          );
        },
      ),
    );
  }
}

class GroupedListViewWidget extends StatelessWidget {
  final List<LogMessage> lines;
  final void Function()? loadAll;

  const GroupedListViewWidget({super.key, required this.lines, required this.loadAll});

  @override
  Widget build(BuildContext context) {
    const timeThreshold = Duration(seconds: 2);
    final timeFormat = DateFormat('dd.MM.yy HH:mm:ss');

    // Helper to group by time clusters
    String groupByTimeCluster(DateTime timestamp) {
      final normalizedTime = timestamp.millisecondsSinceEpoch ~/ timeThreshold.inMilliseconds;
      return timeFormat.format(DateTime.fromMillisecondsSinceEpoch(normalizedTime * timeThreshold.inMilliseconds));
    }

    return GroupedListView<LogMessage, String>(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elements: lines,
      groupBy: (line) => groupByTimeCluster(line.time),
      groupHeaderBuilder: (msg) => ListTile(title: Text(timeFormat.format(msg.time))),
      itemComparator: (a, b) => a.time.compareTo(b.time),
      useStickyGroupSeparators: true,
      stickyHeaderBackgroundColor: const Color(0xFF202020),
      order: GroupedListOrder.DESC,
      footer: loadAll == null
          ? null
          : ElevatedButton(
              onPressed: loadAll,
              child: const Text("Load all"),
            ),
      itemBuilder: (context, line) {
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
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => LogMessageDetailsPage(message: line),
                        ),
                      );
                    },
                    child: Text(
                      line.message,
                      style: const TextStyle(fontFamily: "RobotoMono"),
                      maxLines: 3,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Clipboard.setData(ClipboardData(text: jsonEncode(line.toJson()))),
                  icon: const Icon(Icons.copy, size: 18),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LogMessageDetailsPage extends StatefulWidget {
  final LogMessage message;

  const LogMessageDetailsPage({super.key, required this.message});

  @override
  State<LogMessageDetailsPage> createState() => _LogMessageDetailsPageState();
}

class _LogMessageDetailsPageState extends State<LogMessageDetailsPage> {
  late bool wrapLines = !Platform.isAndroid || !widget.message.message.replaceFirst("\n", "").contains("\n");

  @override
  Widget build(BuildContext context) {
    final errorText = Text(
      widget.message.message,
      style: const TextStyle(fontFamily: "RobotoMono", fontSize: 11),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Log Message Details"),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Logged at ${widget.message.time}"),
                const SizedBox(height: 8),
                Wrap(
                  children: [
                    const Text("Severity: "),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: widget.message.level.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(widget.message.level.name),
                    )
                  ],
                ),
              ],
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wrapLines) ...[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: errorText,
                  ),
                ] else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    child: errorText,
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Clipboard.setData(ClipboardData(text: widget.message.message)),
                        icon: const Icon(Icons.copy),
                      ),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text("Wrap"),
                          Checkbox(value: wrapLines, onChanged: (value) => setState(() => wrapLines = value ?? wrapLines)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Clipboard.setData(ClipboardData(text: jsonEncode(widget.message.toJson()))),
        child: const Icon(Icons.copy),
      ),
    );
  }
}
