import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';

Alignment polarToAlignment(final double deg) => Alignment(cosD(deg), -sinD(deg));

Vector2 polarToCartesian(double deg, double radius) => Vector2(cosD(deg) * radius, sinD(deg) * radius);

Vector2 polarToCartesianRad(double rad, double radius) => Vector2(cos(rad) * radius, sin(rad) * radius);

double sinD(double deg) => sin(deg * degrees2Radians);

double cosD(double deg) => cos(deg * degrees2Radians);

Offset vecToOffset(final Vector2 vec) => Offset(vec.x, -vec.y);

Vector2 centerOfCircle(final double radius, final double angle, final bool left) {
  Vector2 center = polarToCartesian(angle + 90, radius);

  if (!left) {
    center = polarToCartesian(-90 - angle, radius);
    center = Vector2(-center.x, center.y);
  }

  return center;
}

bool isLineIntersectingAABB(final Aabb2 aabb2, final Vector2 p1, final Vector2 p2) {
  double tmin = 0.0;
  double tmax = 1.0;

  final aabbMin = aabb2.min;
  final aabbMax = aabb2.max;

  for (int i = 0; i < 2; i++) {
    final direction = i == 0 ? p2.x - p1.x : p2.y - p1.y;
    final min = i == 0 ? aabbMin.x : aabbMin.y;
    final max = i == 0 ? aabbMax.x : aabbMax.y;
    final origin = i == 0 ? p1.x : p1.y;

    if (direction.abs() < 1e-9) {
      if (origin < min || origin > max) return false;
    } else {
      double t1 = (min - origin) / direction;
      double t2 = (max - origin) / direction;

      if (t1 > t2) {
        final temp = t1;
        t1 = t2;
        t2 = temp;
      }

      tmin = tmin > t1 ? tmin : t1;
      tmax = tmax < t2 ? tmax : t2;

      if (tmin > tmax) return false;
    }
  }

  return true;
}

bool isLineVisibleFast(final Aabb2 visibleArea, final Vector2 p1, final Vector2 p2) => isLineIntersectingAABB(visibleArea, p1, p2);

Rect copyRectWith(final Rect rect, {double? left, double? top, double? width, double? height}) => Rect.fromLTWH(
    left ?? rect.left,
    top ?? rect.top,
    width ?? rect.width,
    height ?? rect.height,
  );

Offset copyOffsetWith(final Offset offset, {double? dx, double? dy}) => Offset(
    dx ?? offset.dx,
    dy ?? offset.dy,
  );
