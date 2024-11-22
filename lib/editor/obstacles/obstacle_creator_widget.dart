import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_pilot/editor/obstacles/obstacle_settings/circle_obstacle_settings.dart';

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

  final Map<Obstacle, Image> cachedImages = {};

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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(obstacles[i].details),
                if (obstacles[i] is ImageObstacle && (obstacles[i] as ImageObstacle).image != null) ...[
                  const SizedBox(height: 10),
                  imagePreview(obstacles[i] as ImageObstacle),
                ],
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
          cachedImage: cachedImages[ob],
          onImageChanged: (image) {
            setState(() {
              if (image == null) {
                cachedImages.remove(ob);
                return;
              }
              cachedImages[ob] = image;
            });
          },
        );
    }
  }

  Widget imagePreview(ImageObstacle ob) {
    final cachedImage = cachedImages[ob];

    if (cachedImage != null) return cachedImage;

    return FutureBuilder(
      future: ob.image!.toByteData(format: ImageByteFormat.png),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          cachedImages[ob] = Image.memory(
            snapshot.data!.buffer.asUint8List(),
            height: 200,
          );
          return cachedImages[ob]!;
        }
        return const CircularProgressIndicator();
      },
    );
  }
}
