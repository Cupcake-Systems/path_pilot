import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_pilot/editor/obstacles/obstacle_settings/circle_obstacle_settings.dart';

import 'obstacle.dart';
import 'obstacle_settings/rectangle_obstacle_settings.dart';

class ObstacleCreator extends StatefulWidget {
  final void Function(List<Obstacle> newObstacles) onObstaclesChange;
  final List<Obstacle> obstacles;

  const ObstacleCreator({
    super.key,
    required this.onObstaclesChange,
    required this.obstacles,
  });

  @override
  State<ObstacleCreator> createState() => _ObstacleCreatorState();
}

class _ObstacleCreatorState extends State<ObstacleCreator> {
  late final List<Obstacle> obstacles = List.from(widget.obstacles);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obstacle Creator'),
      ),
      body: ReorderableListView.builder(
        itemCount: obstacles.length,
        itemBuilder: (BuildContext context, int i) {
          return ListTile(
            key: ObjectKey(obstacles[i]),
            title: Text(obstacles[i].name),
            leading: Icon(Obstacle.getIcon(obstacles[i].type), color: obstacles[i].paint.color),
            subtitle: Text(obstacles[i].details),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return StatefulBuilder(builder: (context, setState) {
                          return AlertDialog(
                            title: Text('Edit ${obstacles[i].name}'),
                            clipBehavior: Clip.antiAlias,
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                                    child: DropdownMenu(
                                      initialSelection: obstacles[i].type,
                                      label: const Text('Obstacle Type'),
                                      dropdownMenuEntries: ObstacleType.values
                                          .map(
                                            (type) => DropdownMenuEntry(value: type, label: Obstacle.getName(type)),
                                          )
                                          .toList(),
                                      onSelected: (value) => setState(() {
                                        switch (value!) {
                                          case ObstacleType.rectangle:
                                            obstacles[i] = RectangleObstacle.base();
                                            break;
                                          case ObstacleType.circle:
                                            obstacles[i] = CircleObstacle.base();
                                            break;
                                        }
                                      }),
                                    ),
                                  ),
                                  buildObstacleSettings(i),
                                  ElevatedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(obstacles[i]),
                                    label: const Text('Done'),
                                    icon: const Icon(Icons.check),
                                  ),
                                  if (!Platform.isAndroid) const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => Navigator.of(context).pop(),
                                    label: const Text('Cancel'),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                            ),
                          );
                        });
                      },
                    );
                  },
                  icon: const Icon(Icons.edit),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => setState(() => obstacles.removeAt(i)),
                  icon: const Icon(Icons.delete),
                ),
                const SizedBox(width: 20),
              ],
            ),
          );
        },
        onReorder: (int oldIndex, int newIndex) {
          if (oldIndex < newIndex) --newIndex;
          setState(() => obstacles.insert(newIndex, obstacles.removeAt(oldIndex)));
          widget.onObstaclesChange(obstacles);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          setState(() {
            obstacles.add(RectangleObstacle.base());
          });
          widget.onObstaclesChange(obstacles);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget buildObstacleSettings(int obstacleIndex) {
    final ob = obstacles[obstacleIndex];

    if (ob is RectangleObstacle) {
      return RectangleObstacleSettings(
        obstacle: ob,
        onObstacleChanged: (obstacle) {
          setState(() {
            obstacles[obstacleIndex] = obstacle;
          });
          widget.onObstaclesChange(obstacles);
        },
      );
    } else if (ob is CircleObstacle) {
      return CircleObstacleSettings(
        obstacle: ob,
        onObstacleChanged: (obstacle) {
          setState(() {
            obstacles[obstacleIndex] = obstacle;
          });
          widget.onObstaclesChange(obstacles);
        },
      );
    } else {
      throw Exception('Unknown obstacle type');
    }
  }
}
