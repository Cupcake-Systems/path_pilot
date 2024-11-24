import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_pilot/editor/obstacles/obstacle.dart';
import 'package:path_pilot/helper/file_manager.dart';

class ImageObstacleSettings extends StatefulWidget {
  final ImageObstacle obstacle;
  final void Function(ImageObstacle obstacle) onObstacleChanged;
  final Image? cachedImage;
  final void Function(Image? img) onImageChanged;

  const ImageObstacleSettings({
    super.key,
    required this.obstacle,
    required this.onObstacleChanged,
    required this.cachedImage,
    required this.onImageChanged,
  });

  @override
  State<ImageObstacleSettings> createState() => _ImageObstacleSettingsState();
}

class _ImageObstacleSettingsState extends State<ImageObstacleSettings> {
  late bool lockAspectRatio = widget.obstacle.image == null || (imgAspectRatio - widget.obstacle.w / widget.obstacle.h).abs() < 1e-5;

  late final initialHeightText = (widget.obstacle.h * 100).toStringAsFixed(2);
  late final initialWidthText = (widget.obstacle.w * 100).toStringAsFixed(2);

  late final heightController = TextEditingController(text: initialHeightText);
  late final widthController = TextEditingController(text: initialWidthText);

  double get imgAspectRatio => widget.obstacle.image!.width / widget.obstacle.image!.height;

  late Image? cachedImage = widget.cachedImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.bottom,
          children: [
            TableRow(
              children: [
                TextFormField(
                  initialValue: (widget.obstacle.x * 100).toStringAsFixed(2),
                  decoration: const InputDecoration(labelText: 'X in cm'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed == null) return;
                    widget.obstacle.x = parsed / 100;
                    widget.onObstacleChanged(widget.obstacle);
                  },
                ),
                const SizedBox(width: 16),
                TextFormField(
                  initialValue: (widget.obstacle.y * 100).toStringAsFixed(2),
                  decoration: const InputDecoration(labelText: 'Y in cm'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed == null) return;
                    widget.obstacle.y = parsed / 100;
                    widget.onObstacleChanged(widget.obstacle);
                  },
                ),
              ],
            ),
            if (widget.obstacle.image != null) ...[
              const TableRow(
                children: [
                  SizedBox(height: 10),
                  SizedBox(height: 0),
                  SizedBox(height: 0),
                ],
              ),
              TableRow(
                children: [
                  TextFormField(
                    controller: widthController,
                    decoration: const InputDecoration(labelText: 'Width in cm'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed == null) return;
                      widget.obstacle.w = parsed / 100;
                      if (lockAspectRatio) {
                        heightController.text = (widget.obstacle.h * 100).toStringAsFixed(2);
                      }
                      widget.onObstacleChanged(widget.obstacle);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: IconButton(
                      onPressed: () {
                        setState(() => lockAspectRatio = !lockAspectRatio);
                        if (lockAspectRatio) {
                          widget.obstacle.h = widget.obstacle.w / imgAspectRatio;
                          heightController.text = (widget.obstacle.h * 100).toStringAsFixed(2);
                        }
                        widget.onObstacleChanged(widget.obstacle);
                      },
                      icon: Icon(lockAspectRatio ? Icons.lock : Icons.lock_open),
                    ),
                  ),
                  TextFormField(
                    controller: heightController,
                    decoration: const InputDecoration(labelText: 'Height in cm'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed == null) return;
                      widget.obstacle.h = parsed / 100;
                      if (lockAspectRatio) {
                        widget.obstacle.w = widget.obstacle.h * imgAspectRatio;
                        widthController.text = (widget.obstacle.w * 100).toStringAsFixed(2);
                      }
                      widget.onObstacleChanged(widget.obstacle);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (widget.obstacle.image != null) ...[
          imagePreview(widget.obstacle),
          const SizedBox(height: 10),
        ],
        ElevatedButton.icon(
          onPressed: () async {
            final imgPath = await pickSingleFile(context: context);
            if (imgPath == null) return;
            final imageSuccessfullySet = await widget.obstacle.setImg(imgPath);

            setState(() {
              if (!imageSuccessfullySet) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to load image")));
                }
                return;
              }
              cachedImage = null;
              if (widget.obstacle.image == null) return;
              widget.obstacle.w = widget.obstacle.image!.width / 1e3;
              widget.obstacle.h = widget.obstacle.image!.height / 1e3;
            });

            widthController.text = (widget.obstacle.w * 100).toStringAsFixed(2);
            heightController.text = (widget.obstacle.h * 100).toStringAsFixed(2);
            widget.onObstacleChanged(widget.obstacle);
          },
          icon: const Icon(Icons.image),
          label: const Text('Select image'),
        ),
        if (!Platform.isAndroid) const SizedBox(height: 10),
      ],
    );
  }

  Widget imagePreview(ImageObstacle ob) {
    if (cachedImage != null) return cachedImage!;

    return FutureBuilder(
      future: ob.image!.toByteData(format: ImageByteFormat.png),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          cachedImage = Image.memory(
            snapshot.data!.buffer.asUint8List(),
            height: 200,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onImageChanged(cachedImage));
          return cachedImage!;
        }
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}
