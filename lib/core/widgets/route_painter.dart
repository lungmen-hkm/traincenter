import 'dart:math' as math;

import 'package:flutter/material.dart';
// `latlong2` also exports a `Path` class for geographic paths, which clashes
// with the `dart:ui` `Path` used by the painter.
import 'package:latlong2/latlong.dart' hide Path;

/// Draws a recorded route as a pure vector polyline.
///
/// The painter is completely independent from any tile provider, which makes
/// it the perfect fit for the transparent PNG export: the exported image
/// contains the *geometry* of the ride, not a screenshot of a map.
///
/// Every colour is provided by the caller (which reads it from the ambient
/// [ColorScheme]); the painter itself contains no colour literals.
class RoutePainter extends CustomPainter {
  /// Creates a route painter.
  const RoutePainter({
    required this.points,
    required this.color,
    this.borderColor,
    this.strokeWidth = 6,
    this.borderStrokeWidth = 2,
    this.showEndpoints = true,
    this.endpointRadius = 6,
    this.padding = 24,
  });

  /// The route geometry.
  final List<LatLng> points;

  /// Colour of the route stroke.
  final Color color;

  /// Colour of the casing drawn below the stroke.
  final Color? borderColor;

  /// Width of the route stroke.
  final double strokeWidth;

  /// Width of the casing drawn below the stroke.
  final double borderStrokeWidth;

  /// Whether the start and end markers are drawn.
  final bool showEndpoints;

  /// Radius of the start / end markers.
  final double endpointRadius;

  /// Empty space kept around the route.
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      if (points.length == 1 && showEndpoints) {
        _drawEndpoint(canvas, size, points.first, radius: endpointRadius);
      }
      return;
    }

    final offsets = project(points, size, padding);

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      final previous = offsets[i - 1];
      final current = offsets[i];
      // Smooth the polyline with quadratic curves through the midpoints.
      final midX = (previous.dx + current.dx) / 2;
      final midY = (previous.dy + current.dy) / 2;
      path.quadraticBezierTo(previous.dx, previous.dy, midX, midY);
    }
    path.lineTo(offsets.last.dx, offsets.last.dy);

    if (borderColor != null && borderStrokeWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + borderStrokeWidth * 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = borderColor!,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    if (showEndpoints) {
      _drawEndpoint(canvas, size, points.first, radius: endpointRadius);
      _drawEndpoint(canvas, size, points.last, radius: endpointRadius);
    }
  }

  /// Draws a single endpoint marker.
  void _drawEndpoint(Canvas canvas, Size size, LatLng point, {required double radius}) {
    final offsets = project(<LatLng>[point], size, padding);
    final center = offsets.first;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showEndpoints != showEndpoints;
  }
}

/// Projects a list of coordinates onto the canvas.
///
/// The projection preserves the aspect ratio of the route so that the shape
/// of the ride is not distorted. It is intentionally simple (equirectangular
/// with a latitude based longitude correction) because a route only spans a
/// few kilometres.
List<Offset> project(
  List<LatLng> points,
  Size size, [
  double padding = 24,
]) {
  if (points.isEmpty) return const <Offset>[];

  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;

  for (final point in points) {
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
    if (point.longitude < minLng) minLng = point.longitude;
    if (point.longitude > maxLng) maxLng = point.longitude;
  }

  final meanLat = (minLat + maxLat) / 2;
  final lngScale = math.cos(meanLat * math.pi / 180.0);

  final spanX = (maxLng - minLng) * lngScale;
  final spanY = maxLat - minLat;

  final availableWidth = size.width - padding * 2;
  final availableHeight = size.height - padding * 2;

  if (spanX <= 0 && spanY <= 0) {
    return <Offset>[
      Offset(size.width / 2, size.height / 2),
    ];
  }

  final scale = <double>[
    if (spanX > 0) availableWidth / spanX,
    if (spanY > 0) availableHeight / spanY,
  ].reduce((a, b) => a < b ? a : b);

  final offsetX = size.width / 2;
  final offsetY = size.height / 2;

  return points.map((point) {
    final x = (point.longitude - minLng) * lngScale * scale;
    final y = (maxLat - point.latitude) * scale;
    return Offset(offsetX + x - (spanX * scale) / 2, offsetY + y - (spanY * scale) / 2);
  }).toList(growable: false);
}

