import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';

/// One tile in the standard slippy-map pyramid.
class OfflineTileCoordinate {
  /// Creates a tile coordinate.
  const OfflineTileCoordinate({
    required this.z,
    required this.x,
    required this.y,
  });

  /// Zoom level.
  final int z;

  /// Column.
  final int x;

  /// Row.
  final int y;

  /// Relative path used by [OfflineMapStore].
  String get relativePath => '$z/$x/$y.png';
}

/// Web-Mercator tile maths shared by the download planner and the UI.
abstract final class SlippyMapTiles {
  /// Web-Mercator latitude limit.
  static const double maxMercatorLatitude = 85.05112878;

  /// Counts the tiles needed for [bounds] between [minZoom] and [maxZoom].
  static int tileCount(LatLngBounds bounds, int minZoom, int maxZoom) {
    if (maxZoom < minZoom) return 0;

    var count = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      final yRange = _yRange(bounds, z);
      final yCount = yRange.max - yRange.min + 1;
      for (final range in _xRanges(bounds, z)) {
        count += (range.max - range.min + 1) * yCount;
      }
    }
    return count;
  }

  /// Enumerates the tiles needed for [bounds] between [minZoom] and [maxZoom].
  static Iterable<OfflineTileCoordinate> tiles(
    LatLngBounds bounds,
    int minZoom,
    int maxZoom,
  ) sync* {
    if (maxZoom < minZoom) return;

    for (var z = minZoom; z <= maxZoom; z++) {
      final yRange = _yRange(bounds, z);
      for (final xRange in _xRanges(bounds, z)) {
        for (var x = xRange.min; x <= xRange.max; x++) {
          for (var y = yRange.min; y <= yRange.max; y++) {
            yield OfflineTileCoordinate(z: z, x: x, y: y);
          }
        }
      }
    }
  }

  static ({int min, int max}) _yRange(LatLngBounds bounds, int zoom) {
    final north = _tileY(bounds.north, zoom);
    final south = _tileY(bounds.south, zoom);
    return (min: math.min(north, south), max: math.max(north, south));
  }

  static List<({int min, int max})> _xRanges(LatLngBounds bounds, int zoom) {
    final west = _tileX(bounds.west, zoom);
    final east = _tileX(bounds.east, zoom);

    // A viewport that crosses the antimeridian has west > east in tile
    // coordinates. Treat it as two ranges instead of dropping the wrapped part.
    if (west <= east) {
      return <({int min, int max})>[(min: west, max: east)];
    }
    return <({int min, int max})>[
      (min: west, max: (1 << zoom) - 1),
      (min: 0, max: east),
    ];
  }

  static int _tileX(double longitude, int zoom) {
    final tiles = 1 << zoom;
    final x = ((longitude + 180.0) / 360.0 * tiles).floor();
    return x.clamp(0, tiles - 1).toInt();
  }

  static int _tileY(double latitude, int zoom) {
    final tiles = 1 << zoom;
    final clamped = latitude.clamp(-maxMercatorLatitude, maxMercatorLatitude);
    final radians = clamped * math.pi / 180.0;
    final y =
        ((1.0 -
                    math.log(math.tan(radians) + 1.0 / math.cos(radians)) /
                        math.pi) /
                2.0 *
                tiles)
            .floor();
    return y.clamp(0, tiles - 1).toInt();
  }
}
