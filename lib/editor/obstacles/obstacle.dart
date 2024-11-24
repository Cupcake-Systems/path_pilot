import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

abstract class Obstacle {
  final Paint paint;

  static Paint get defaultPaint => Paint()..color = Colors.grey;

  const Obstacle({required this.paint});

  void draw(final Canvas canvas);

  ObstacleType get type;

  String get name => getName(type);

  Map<String, dynamic> toJson();

  static IconData getIcon(ObstacleType type) {
    switch (type) {
      case ObstacleType.rectangle:
        return Icons.square;
      case ObstacleType.circle:
        return Icons.circle;
      case ObstacleType.image:
        return Icons.image;
    }
  }

  static String getName(ObstacleType type) {
    switch (type) {
      case ObstacleType.rectangle:
      case ObstacleType.circle:
      case ObstacleType.image:
        return "${type.name[0].toUpperCase()}${type.name.substring(1)}";
    }
  }

  String get details;

  bool isVisible(final Rect visibleArea);
}

class RectangleObstacle extends Obstacle {
  Rect rect;

  RectangleObstacle({
    required super.paint,
    required this.rect,
  });

  @override
  void draw(final Canvas canvas) {
    canvas.drawRect(rect, paint);
  }

  RectangleObstacle.fromJson(Map<String, dynamic> json)
      : rect = Rect.fromLTWH(
          json["x"],
          json["y"],
          json["w"],
          json["h"],
        ),
        super(paint: Paint()..color = Color(json["color"]));

  @override
  Map<String, dynamic> toJson() => {
        "color": paint.color.value,
        "x": rect.left,
        "y": rect.top,
        "w": rect.width,
        "h": rect.height,
      };

  @override
  ObstacleType get type => ObstacleType.rectangle;

  static RectangleObstacle base() => RectangleObstacle(paint: Obstacle.defaultPaint, rect: Rect.fromCircle(center: Offset.zero, radius: 0.1));

  @override
  String get details =>
      "Top left corner: (${(rect.left * 100).toStringAsFixed(2)}, ${(rect.top * 100).toStringAsFixed(2)})cm\nWidth: ${(rect.width * 100).toStringAsFixed(2)}cm\nHeight: ${(rect.height * 100).toStringAsFixed(2)}cm";

  @override
  bool isVisible(Rect visibleArea) => true;
}

class CircleObstacle extends Obstacle {
  Offset center;
  double radius;

  CircleObstacle({
    required super.paint,
    required this.center,
    required this.radius,
  });

  @override
  void draw(final Canvas canvas) => canvas.drawCircle(center, radius, paint);

  @override
  Map<String, dynamic> toJson() => {
        "color": paint.color.value,
        "x": center.dx,
        "y": center.dy,
        "r": radius,
      };

  CircleObstacle.fromJson(Map<String, dynamic> json)
      : center = Offset(json["x"], json["y"]),
        radius = json["r"],
        super(paint: Paint()..color = Color(json["color"]));

  @override
  ObstacleType get type => ObstacleType.circle;

  static CircleObstacle base() => CircleObstacle(paint: Obstacle.defaultPaint, center: Offset.zero, radius: 0.1);

  @override
  String get details => "Center: (${(center.dx * 100).toStringAsFixed(2)}, ${(center.dy * 100).toStringAsFixed(2)})cm\nRadius: ${(radius * 100).toStringAsFixed(2)}cm";

  @override
  bool isVisible(Rect visibleArea) {
    return true;
  }
}

class ImageObstacle extends Obstacle {
  Offset offset;
  Size size;
  ui.Image? _image;
  String? _imagePath;

  ui.Image? get image => _image;

  String? get imagePath => _imagePath;

  Future<bool> setImg(String newImgPath) async {
    try {
      final bytes = await File(newImgPath).readAsBytes();
      _image = await decodeImageFromList(bytes);
      _imagePath = newImgPath;
    } catch (e) {
      return false;
    }
    return true;
  }

  ImageObstacle({
    required super.paint,
    required this.offset,
    required this.size,
    required ui.Image? img,
    required String? imgPath,
  })  : _image = img,
        _imagePath = imgPath;

  static Future<ImageObstacle?> create({
    required Paint paint,
    required Offset offset,
    required Size size,
    required String? imgPath,
  }) async {
    try {
      ui.Image? img;
      if (imgPath != null) {
        final bytes = await File(imgPath).readAsBytes();
        img = await decodeImageFromList(bytes);
      }
      return ImageObstacle(paint: paint, offset: offset, size: size, img: img, imgPath: imgPath);
    } catch (e) {
      // failed to load image
    }
    return null;
  }

  static Future<ImageObstacle?> fromJson(Map<String, dynamic> json) => ImageObstacle.create(
        paint: Paint()..color = Color(json["color"]),
        offset: Offset(json["x"], json["y"]),
        size: Size(json["w"], json["h"]),
        imgPath: json["img_path"],
      );

  @override
  String get details {
    if (image == null) return "Image not loaded";

    final sizeS = "Width: ${(size.width * 100).toStringAsFixed(2)}cm\nHeight: ${(size.height * 100).toStringAsFixed(2)}cm";

    return """
Top left corner: (${(offset.dx * 100).toStringAsFixed(2)}, ${(offset.dy * 100).toStringAsFixed(2)})cm
$sizeS
Image location: $_imagePath""";
  }

  @override
  void draw(Canvas canvas) {
    if (image == null) return;
    final sw = size.width / image!.width;
    final sh = size.height / image!.height;
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(sw, sh);
    canvas.drawImage(image!, Offset.zero, paint);
  }

  static Future<ImageObstacle> base() async => (await create(
        paint: Obstacle.defaultPaint,
        offset: Offset.zero,
        size: const Size(0.1, 0.1),
        imgPath: null,
      ))!;

  @override
  bool isVisible(Rect visibleArea) => true;

  @override
  Map<String, dynamic> toJson() {
    if (image == null) return {};
    return {
      "color": paint.color.value,
      "x": offset.dx,
      "y": offset.dy,
      "img_path": _imagePath,
      "w": size.width,
      "h": size.height,
    };
  }

  @override
  ObstacleType get type => ObstacleType.image;
}

enum ObstacleType {
  rectangle,
  circle,
  image,
}
