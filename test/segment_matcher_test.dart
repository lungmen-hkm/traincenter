import 'package:flutter_test/flutter_test.dart';
import 'package:traincenter/data/models/segment.dart';
import 'package:traincenter/data/models/segment_effort.dart';
import 'package:traincenter/data/models/track_point.dart';
import 'package:traincenter/domain/services/segment_matcher.dart';

/// Builds a synthetic track that runs straight east along the equator.
List<TrackPoint> buildTrack({
  required double startLon,
  required double endLon,
  required int samples,
  required int secondsPerSample,
  double lat = 0,
}) {
  final points = <TrackPoint>[];
  final start = DateTime.utc(2026, 1, 1, 8);
  for (var i = 0; i < samples; i++) {
    final ratio = i / (samples - 1);
    points.add(
      TrackPoint(
        seq: i,
        latitude: lat,
        longitude: startLon + (endLon - startLon) * ratio,
        altitude: 10,
        timestamp: start.add(Duration(seconds: i * secondsPerSample)),
      ),
    );
  }
  return points;
}

/// Builds a segment that covers the first half of the track.
Segment buildSegment({double startLon = 0, double endLon = 0.005}) {
  return Segment(
    id: 1,
    name: 'Test segment',
    startLatitude: 0,
    startLongitude: startLon,
    endLatitude: 0,
    endLongitude: endLon,
    distanceMeters: 555,
    createdAt: DateTime.utc(2026),
  );
}

void main() {
  group('SegmentMatcher', () {
    test('matches a track that traverses the segment', () {
      final points = buildTrack(
        startLon: 0,
        endLon: 0.01,
        samples: 21,
        secondsPerSample: 2,
      );
      final segment = buildSegment();

      final matches = SegmentMatcher.match(
        segments: <Segment>[segment],
        points: points,
      );

      expect(matches, hasLength(1));
      // The segment spans the first 10 samples -> 20 seconds.
      expect(matches.single.timeMs, closeTo(20000, 1500));
      expect(matches.single.avgSpeedMps, greaterThan(0));
      expect(matches.single.isPersonalBest, isTrue);
    });

    test('does not match a track that never reaches the segment', () {
      final points = buildTrack(
        startLon: 1,
        endLon: 1.01,
        samples: 21,
        secondsPerSample: 2,
      );

      final matches = SegmentMatcher.match(
        segments: <Segment>[buildSegment()],
        points: points,
      );

      expect(matches, isEmpty);
    });

    test('flags a slower effort as a non personal best', () {
      final points = buildTrack(
        startLon: 0,
        endLon: 0.01,
        samples: 41,
        secondsPerSample: 2,
      );
      final segment = buildSegment();

      final matches = SegmentMatcher.match(
        segments: <Segment>[segment],
        points: points,
        bestEfforts: <int, SegmentEffort>{
          1: SegmentEffort(
            id: 1,
            segmentId: 1,
            activityId: 1,
            timeMs: 1000,
            avgSpeedMps: 0.55,
            achievedAt: DateTime.utc(2026),
          ),
        },
      );

      expect(matches, hasLength(1));
      expect(matches.single.isPersonalBest, isFalse);
      expect(matches.single.previousBestTimeMs, 1000);
      expect(matches.single.timeMs, greaterThan(1000));
    });

    test('flags a faster effort as a personal best', () {
      final points = buildTrack(
        startLon: 0,
        endLon: 0.01,
        samples: 21,
        secondsPerSample: 2,
      );

      final matches = SegmentMatcher.match(
        segments: <Segment>[buildSegment()],
        points: points,
        bestEfforts: <int, SegmentEffort>{
          1: SegmentEffort(
            id: 1,
            segmentId: 1,
            activityId: 1,
            timeMs: 600000,
            avgSpeedMps: 0.001,
            achievedAt: DateTime.utc(2026),
          ),
        },
      );

      expect(matches, hasLength(1));
      expect(matches.single.isPersonalBest, isTrue);
    });

    test('ignores tracks with too few samples', () {
      final matches = SegmentMatcher.match(
        segments: <Segment>[buildSegment()],
        points: const <TrackPoint>[],
      );
      expect(matches, isEmpty);
    });
  });

  group('fastestEffort', () {
    test('returns the quickest effort', () {
      final efforts = <SegmentEffort>[
        SegmentEffort(
          id: 1,
          segmentId: 1,
          activityId: 1,
          timeMs: 30000,
          avgSpeedMps: 1,
          achievedAt: DateTime.utc(2026),
        ),
        SegmentEffort(
          id: 2,
          segmentId: 1,
          activityId: 2,
          timeMs: 25000,
          avgSpeedMps: 1.2,
          achievedAt: DateTime.utc(2026),
        ),
      ];

      expect(fastestEffort(efforts)?.id, 2);
      expect(fastestEffort(const <SegmentEffort>[]), isNull);
    });
  });
}
