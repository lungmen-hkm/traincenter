import 'dart:math' as math;

/// Minimal geographic helpers used by the recording pipeline and the segment
/// matcher.
///
/// The formulas are intentionally dependency free so the core logic stays
/// unit-testable without any platform channel.
abstract final class GeoUtils {
  /// Earth's mean radius in metres (WGS84 / IUGG).
  static const double earthRadiusMeters = 6371008.8;

  /// Calculates the great-circle distance between two WGS84 coordinates using
  /// the haversine formula.
  static double distanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final phi1 = _radians(lat1);
    final phi2 = _radians(lat2);
    final dPhi = _radians(lat2 - lat1);
    final dLambda = _radians(lon2 - lon1);

    final a = math.pow(math.sin(dPhi / 2), 2) +
        math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dLambda / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Converts a WGS84 coordinate pair into local metric (east / north)
  /// coordinates using an equirectangular projection centred on [origin].
  ///
  /// The projection is accurate enough for the short distances a segment
  /// covers and is orders of magnitude cheaper than a full projection.
  static ({double east, double north}) toLocalMeters({
    required double lat,
    required double lon,
    required double originLat,
    required double originLon,
  }) {
    final metersPerDegreeLat = math.pi * earthRadiusMeters / 180.0;
    final metersPerDegreeLon =
        metersPerDegreeLat * math.cos(_radians(originLat));

    return (
      east: (lon - originLon) * metersPerDegreeLon,
      north: (lat - originLat) * metersPerDegreeLat,
    );
  }

  /// Projects [lat]/[lon] onto the segment running from
  /// ([startLat], [startLon]) to ([endLat], [endLon]).
  ///
  /// The returned record contains:
  ///  * [t] – the normalised position along the segment (0 = start, 1 = end).
  ///  * [distance] – the perpendicular distance (metres) from the segment.
  ///  * [along] – the travelled distance (metres) along the segment.
  static ({double t, double distance, double along}) projectOntoSegment({
    required double lat,
    required double lon,
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) {
    final origin = toLocalMeters(
      lat: startLat,
      lon: startLon,
      originLat: startLat,
      originLon: startLon,
    );
    final point = toLocalMeters(
      lat: lat,
      lon: lon,
      originLat: startLat,
      originLon: startLon,
    );
    final end = toLocalMeters(
      lat: endLat,
      lon: endLon,
      originLat: startLat,
      originLon: startLon,
    );

    final dx = end.east - origin.east;
    final dy = end.north - origin.north;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared == 0) {
      final dxp = point.east - origin.east;
      final dyp = point.north - origin.north;
      return (t: 0.0, distance: math.sqrt(dxp * dxp + dyp * dyp), along: 0.0);
    }

    final px = point.east - origin.east;
    final py = point.north - origin.north;

    final t = (px * dx + py * dy) / lengthSquared;
    final clampedT = t.clamp(0.0, 1.0);

    final closestX = origin.east + clampedT * dx;
    final closestY = origin.north + clampedT * dy;
    final ex = point.east - closestX;
    final ey = point.north - closestY;

    return (
      t: clampedT,
      distance: math.sqrt(ex * ex + ey * ey),
      along: clampedT * math.sqrt(lengthSquared),
    );
  }

  /// Length of the segment between two coordinates in metres.
  static double segmentLengthMeters({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) =>
      distanceMeters(
        lat1: startLat,
        lon1: startLon,
        lat2: endLat,
        lon2: endLon,
      );

  /// Returns the point of [points] that is closest to the given coordinate.
  ///
  /// [points] is a list of `(lat, lon)` records. Returns `null` when the
  /// list is empty.
  static ({double lat, double lon, double distance, int index})? closestPoint({
    required List<({double lat, double lon})> points,
    required double lat,
    required double lon,
  }) {
    if (points.isEmpty) return null;

    var bestIndex = 0;
    var bestDistance = double.infinity;

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final d = distanceMeters(lat1: lat, lon1: lon, lat2: p.lat, lon2: p.lon);
      if (d < bestDistance) {
        bestDistance = d;
        bestIndex = i;
      }
    }

    return (
      lat: points[bestIndex].lat,
      lon: points[bestIndex].lon,
      distance: bestDistance,
      index: bestIndex,
    );
  }

  /// Converts degrees to radians.
  static double _radians(double degrees) => degrees * math.pi / 180.0;
}
