import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/models/segment.dart';
import '../../data/models/segment_effort.dart';
import '../../data/models/track_point.dart';

/// The result of matching a recorded track against a segment.
class SegmentMatch {
  /// The segment that was matched.
  final Segment segment;

  /// Time taken to traverse the segment (milliseconds).
  final int timeMs;

  /// Average speed across the segment (metres per second).
  final double avgSpeedMps;

  /// Whether this match beats the previously stored personal best.
  final bool isPersonalBest;

  /// The previously stored personal best time (milliseconds), if any.
  final int? previousBestTimeMs;

  const SegmentMatch({
    required this.segment,
    required this.timeMs,
    required this.avgSpeedMps,
    required this.isPersonalBest,
    this.previousBestTimeMs,
  });
}

/// Matches recorded GPS tracks against locally defined segments.
///
/// This is deliberately free of any Flutter or persistence dependency so it
/// can be unit tested in isolation.
abstract final class SegmentMatcher {
  /// Matches [points] against [segments].
  ///
  /// [bestEfforts] holds the currently stored personal best for each segment
  /// (keyed by segment id) so a new personal best can be detected.
  static List<SegmentMatch> match({
    required List<Segment> segments,
    required List<TrackPoint> points,
    Map<int, SegmentEffort> bestEfforts = const <int, SegmentEffort>{},
  }) {
    if (segments.isEmpty || points.length < 2) return const <SegmentMatch>[];

    final matches = <SegmentMatch>[];

    for (final segment in segments) {
      final match = matchSegment(
        segment: segment,
        points: points,
        previousBestTimeMs: bestEfforts[segment.id]?.timeMs,
      );
      if (match != null) matches.add(match);
    }

    return matches;
  }

  /// Matches a single [segment] against a recorded track.
  ///
  /// Returns `null` when the track does not traverse the segment.
  static SegmentMatch? matchSegment({
    required Segment segment,
    required List<TrackPoint> points,
    int? previousBestTimeMs,
  }) {
    final projections = <_Projection>[];

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final projection = GeoUtils.projectOntoSegment(
        lat: point.latitude,
        lon: point.longitude,
        startLat: segment.startLatitude,
        startLon: segment.startLongitude,
        endLat: segment.endLatitude,
        endLon: segment.endLongitude,
      );
      if (projection.distance > AppConstants.segmentCorridorRadiusMeters) {
        continue;
      }
      projections.add(
        _Projection(
          index: i,
          t: projection.t,
          timestamp: point.timestamp,
        ),
      );
    }

    if (projections.length < 2) return null;

    final run = _bestRun(projections);
    if (run == null) return null;

    final startTime = _crossingTime(run, start: true);
    final endTime = _crossingTime(run, start: false);
    if (startTime == null || endTime == null) return null;

    final timeMs = (endTime - startTime).round();
    if (timeMs <= 0) return null;

    final avgSpeed = segment.distanceMeters / (timeMs / 1000.0);
    final isPersonalBest =
        previousBestTimeMs == null || timeMs < previousBestTimeMs;

    return SegmentMatch(
      segment: segment,
      timeMs: timeMs,
      avgSpeedMps: avgSpeed,
      isPersonalBest: isPersonalBest,
      previousBestTimeMs: previousBestTimeMs,
    );
  }

  /// Splits the corridor points into contiguous runs and returns the run that
  /// covers the largest portion of the segment.
  static List<_Projection>? _bestRun(List<_Projection> projections) {
    const maxGapPoints = 40;

    final runs = <List<_Projection>>[];
    var current = <_Projection>[];

    for (var i = 0; i < projections.length; i++) {
      final projection = projections[i];
      if (current.isNotEmpty) {
        final previous = current.last;
        final gap = projection.index - previous.index;
        // A backwards jump in `t` means the athlete turned around, which
        // starts a new pass over the segment.
        final reversed = projection.t + 0.1 < previous.t;
        if (gap > maxGapPoints || reversed) {
          runs.add(current);
          current = <_Projection>[];
        }
      }
      current.add(projection);
    }
    if (current.isNotEmpty) runs.add(current);

    List<_Projection>? best;
    var bestSpan = 0.0;

    for (final run in runs) {
      final span = run.last.t - run.first.t;
      if (span > bestSpan) {
        bestSpan = span;
        best = run;
      }
    }

    // The pass must cover (almost) the whole segment.
    if (best == null || bestSpan < 0.85) return null;
    return best;
  }

  /// Computes the timestamp at which the track crossed the start (or end) of
  /// the segment, interpolating linearly between the surrounding samples.
  static double? _crossingTime(List<_Projection> run, {required bool start}) {
    const tolerance = 0.02;

    if (start) {
      for (var i = 0; i < run.length; i++) {
        if (run[i].t >= tolerance) {
          if (i == 0) return run[i].timestamp.millisecondsSinceEpoch.toDouble();
          return _interpolate(run[i - 1], run[i], 0.0);
        }
      }
      return null;
    }

    for (var i = run.length - 1; i >= 0; i--) {
      if (run[i].t <= 1.0 - tolerance) {
        if (i == run.length - 1) {
          return run[i].timestamp.millisecondsSinceEpoch.toDouble();
        }
        return _interpolate(run[i], run[i + 1], 1.0);
      }
    }
    return null;
  }

  /// Linearly interpolates the timestamp at which [target] was reached.
  static double _interpolate(_Projection from, _Projection to, double target) {
    final deltaT = to.t - from.t;
    final deltaTime = to.timestamp.millisecondsSinceEpoch -
        from.timestamp.millisecondsSinceEpoch;

    if (deltaT.abs() < 1e-9) {
      return from.timestamp.millisecondsSinceEpoch.toDouble();
    }

    final ratio = ((target - from.t) / deltaT).clamp(0.0, 1.0);
    return from.timestamp.millisecondsSinceEpoch + ratio * deltaTime;
  }
}

/// A single GPS sample projected onto a segment.
class _Projection {
  const _Projection({
    required this.index,
    required this.t,
    required this.timestamp,
  });

  /// Index of the sample in the original track.
  final int index;

  /// Normalised position along the segment (0 = start, 1 = end).
  final double t;

  /// Timestamp of the sample.
  final DateTime timestamp;
}

/// Convenience helper returning the fastest effort of a list.
SegmentEffort? fastestEffort(Iterable<SegmentEffort> efforts) {
  SegmentEffort? best;
  for (final effort in efforts) {
    if (best == null || effort.timeMs < best.timeMs) best = effort;
  }
  return best;
}

/// Clamps a double into the `[min, max]` range.
double clampDouble(double value, double min, double max) =>
    math.max(min, math.min(max, value));
