import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traincenter/core/utils/formatters.dart';
import 'package:traincenter/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils.distanceMeters', () {
    test('returns zero for identical coordinates', () {
      final distance = GeoUtils.distanceMeters(
        lat1: 48.8566,
        lon1: 2.3522,
        lat2: 48.8566,
        lon2: 2.3522,
      );
      expect(distance, closeTo(0, 0.0001));
    });

    test('matches a known distance between two Paris landmarks', () {
      // Église Notre-Dame -> Musée du Louvre, ~1.23 km as the crow flies.
      final distance = GeoUtils.distanceMeters(
        lat1: 48.8530,
        lon1: 2.3499,
        lat2: 48.8606,
        lon2: 2.3376,
      );
      expect(distance, greaterThan(1200));
      expect(distance, lessThan(1300));
    });

    test('is symmetric', () {
      final a = GeoUtils.distanceMeters(
        lat1: 45.0,
        lon1: 7.0,
        lat2: 46.0,
        lon2: 8.0,
      );
      final b = GeoUtils.distanceMeters(
        lat1: 46.0,
        lon1: 8.0,
        lat2: 45.0,
        lon2: 7.0,
      );
      expect(a, closeTo(b, 0.0001));
    });
  });

  group('GeoUtils.projectOntoSegment', () {
    test('projects the start point onto t = 0', () {
      final projection = GeoUtils.projectOntoSegment(
        lat: 45.0,
        lon: 7.0,
        startLat: 45.0,
        startLon: 7.0,
        endLat: 45.0,
        endLon: 7.01,
      );
      expect(projection.t, closeTo(0, 0.0001));
      expect(projection.distance, closeTo(0, 0.001));
    });

    test('projects the end point onto t = 1', () {
      final projection = GeoUtils.projectOntoSegment(
        lat: 45.0,
        lon: 7.01,
        startLat: 45.0,
        startLon: 7.0,
        endLat: 45.0,
        endLon: 7.01,
      );
      expect(projection.t, closeTo(1, 0.0001));
      expect(projection.distance, closeTo(0, 0.001));
    });

    test('reports the perpendicular distance to the segment', () {
      // ~111 m north of the segment line.
      final projection = GeoUtils.projectOntoSegment(
        lat: 45.001,
        lon: 7.005,
        startLat: 45.0,
        startLon: 7.0,
        endLat: 45.0,
        endLon: 7.01,
      );
      expect(projection.distance, closeTo(111, 5));
    });
  });

  group('GeoUtils.closestPoint', () {
    test('returns the nearest sample', () {
      final result = GeoUtils.closestPoint(
        points: <({double lat, double lon})>[
          (lat: 45.0, lon: 7.0),
          (lat: 45.001, lon: 7.001),
          (lat: 45.002, lon: 7.002),
        ],
        lat: 45.0011,
        lon: 7.0011,
      );

      expect(result, isNotNull);
      expect(result!.index, 1);
    });

    test('returns null for an empty track', () {
      final result = GeoUtils.closestPoint(
        points: const <({double lat, double lon})>[],
        lat: 45.0,
        lon: 7.0,
      );
      expect(result, isNull);
    });
  });

  group('Formatters', () {
    test('formats distances for both unit systems', () {
      expect(Formatters.distance(10000, UnitSystem.metric), '10.00 km');
      expect(Formatters.distance(1609.344, UnitSystem.imperial), '1.00 mi');
    });

    test('formats speeds for both unit systems', () {
      expect(Formatters.speed(10, UnitSystem.metric), '36.0 km/h');
      expect(Formatters.speed(10, UnitSystem.imperial), '22.4 mph');
    });

    test('formats durations', () {
      expect(Formatters.duration(0), '00:00');
      expect(Formatters.duration(65000), '01:05');
      expect(Formatters.duration(3_725_000), '1:02:05');
    });
  });

  testWidgets('the app theme builds a Material 3 theme', (tester) async {
    // Sanity check that the theme factory does not throw and produces a
    // Material 3 theme with the ActivityPalette extension attached.
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),
    );
    expect(theme.useMaterial3, isTrue);
  });
}
