import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:path_pilot/editor/obstacles/obstacle_settings/circle_obstacle_settings.dart';
import 'package:path_pilot/helper/file_manager.dart';

import '../../helper/save_system.dart';
import 'obstacle.dart';
import 'obstacle_settings/image_obstacle_settings.dart';
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
  static final Map<String, Image> cachedImages = {};

  String? lastFilePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obstacles'),
      ),
      body: ReorderableListView.builder(
        itemCount: obstacles.length,
        itemBuilder: (BuildContext context, int i) {
          return Column(
            key: ObjectKey(obstacles[i]),
            children: [
              ListTile(
                title: Text(obstacles[i].name),
                leading: Icon(Obstacle.getIcon(obstacles[i].type), color: obstacles[i].paint.color),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(obstacles[i].details),
                    ...imagePreview(obstacles[i]),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return StatefulBuilder(builder: (context, setState1) {
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
                                          onSelected: (value) async {
                                            Obstacle newObstacle;

                                            switch (value!) {
                                              case ObstacleType.rectangle:
                                                newObstacle = RectangleObstacle.base();
                                                break;
                                              case ObstacleType.circle:
                                                newObstacle = CircleObstacle.base();
                                                break;
                                              case ObstacleType.image:
                                                newObstacle = await ImageObstacle.base();
                                                break;
                                            }

                                            setState1(() {
                                              obstacles[i] = newObstacle;
                                            });
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                      buildObstacleSettings(i),
                                      ElevatedButton.icon(
                                        onPressed: () => Navigator.of(context).pop(),
                                        label: const Text('Done'),
                                        icon: const Icon(Icons.check),
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
                      onPressed: () {
                        setState(() => obstacles.removeAt(i));
                        widget.onObstaclesChange(obstacles);
                      },
                      icon: const Icon(Icons.delete),
                    ),
                    if (!Platform.isAndroid) const SizedBox(width: 20),
                  ],
                ),
              ),
              if (i != obstacles.length - 1) const Divider(),
            ],
          );
        },
        onReorder: (int oldIndex, int newIndex) {
          if (oldIndex < newIndex) --newIndex;
          setState(() => obstacles.insert(newIndex, obstacles.removeAt(oldIndex)));
          widget.onObstaclesChange(obstacles);
        },
      ),
      floatingActionButton: ExpandableFab(
        type: ExpandableFabType.up,
        distance: 60,
        childrenAnimation: ExpandableFabAnimation.none,
        children: [
          Row(
            children: [
              FloatingActionButton.small(
                heroTag: 'saveObstacles',
                onPressed: () async {
                  final saveData = SaveData(obstacles: obstacles, instructions: []);
                  final res = await pickFileAndWriteWithStatusMessage(
                    bytes: saveData.toBytes(),
                    context: context,
                    extension: ".robi_script.json",
                  );
                  if (res == null) return;
                  setState(() => lastFilePath = res);
                },
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(10))),
                child: const Icon(Icons.save_as),
              ),
              FloatingActionButton.small(
                heroTag: 'saveObstacles',
                onPressed: lastFilePath == null? null : () {
                  final saveData = SaveData(obstacles: obstacles, instructions: []);
                  writeStringToFileWithStatusMessage(lastFilePath!, saveData.toJson(), context);
                },
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(10))),
                child: const Icon(Icons.save),
              ),
            ],
          ),
          FloatingActionButton.small(
            heroTag: 'loadObstacles',
            onPressed: () async {
              final file = await pickSingleFile(context: context, allowedExtensions: ['json', 'robi_script.json']);
              if (file == null || !context.mounted) return;
              final saveData = await SaveData.fromFileWithStatusMessage(file, context);
              if (saveData == null) return;
              setState(() {
                obstacles.addAll(saveData.obstacles);
              });
              widget.onObstaclesChange(obstacles);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${saveData.obstacles.length} Obstacles loaded')));
            },
            child: const Icon(Icons.file_download_outlined),
          ),
          FloatingActionButton.small(
            heroTag: 'addObstacle',
            onPressed: () async {
              setState(() {
                obstacles.add(RectangleObstacle.base());
              });
              widget.onObstaclesChange(obstacles);
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButtonLocation: ExpandableFab.location,
    );
  }

  Widget buildObstacleSettings(int obstacleIndex) {
    final ob = obstacles[obstacleIndex];
    final obType = ob.type;

    switch (obType) {
      case ObstacleType.rectangle:
        return RectangleObstacleSettings(
          obstacle: ob as RectangleObstacle,
          onObstacleChanged: (obstacle) {
            setState(() {
              obstacles[obstacleIndex] = obstacle;
            });
            widget.onObstaclesChange(obstacles);
          },
        );
      case ObstacleType.circle:
        return CircleObstacleSettings(
          obstacle: ob as CircleObstacle,
          onObstacleChanged: (obstacle) {
            setState(() {
              obstacles[obstacleIndex] = obstacle;
            });
            widget.onObstaclesChange(obstacles);
          },
        );
      case ObstacleType.image:
        return ImageObstacleSettings(
          obstacle: ob as ImageObstacle,
          onObstacleChanged: (obstacle) {
            setState(() {
              obstacles[obstacleIndex] = obstacle;
            });
            widget.onObstaclesChange(obstacles);
          },
          cachedImage: cachedImages[ob.imagePath],
          onImageChanged: (image) {
            setState(() {
              if (image == null) {
                cachedImages.remove(ob.imagePath);
              } else if (ob.imagePath != null) {
                cachedImages[ob.imagePath!] = image;
              }
            });
          },
        );
    }
  }

  List<Widget> imagePreview(Obstacle ob) {
    if (ob is! ImageObstacle) return const [];

    final imgPath = ob.imagePath;

    if (imgPath == null) return const [];

    final cachedImage = cachedImages[imgPath];

    if (cachedImage != null) {
      return [
        const SizedBox(height: 10),
        cachedImage,
      ];
    }

    return [
      FutureBuilder(
        future: ob.image!.toByteData(format: ImageByteFormat.png),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final img = Image.memory(
              snapshot.data!.buffer.asUint8List(),
              height: 200,
            );
            cachedImages[imgPath] = img;
            return img;
          }
          return const CircularProgressIndicator();
        },
      ),
    ];
  }
}
