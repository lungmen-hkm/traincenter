import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:traincenter/core/db/app_database.dart';
import 'package:traincenter/core/services/background_location_service.dart';
import 'package:traincenter/core/services/location_service.dart';
import 'package:traincenter/data/repositories/activity_repository.dart';
import 'package:traincenter/data/repositories/gear_repository.dart';
import 'package:traincenter/data/repositories/segment_repository.dart';
import 'package:traincenter/data/services/segment_effort_service.dart';
import 'package:traincenter/features/record/record_controller.dart';

/// A location service whose fixes can be injected by the test.
class _FakeLocationService implements LocationService {
  final StreamController<LocationFix> fixes =
      StreamController<LocationFix>.broadcast();

  @override
  Future<LocationPermissionState> requestPermission() async =>
      LocationPermissionState.granted;

  @override
  Future<LocationPermissionState> checkPermission() async =>
      LocationPermissionState.granted;

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Stream<LocationFix> watch(LocationTrackingOptions options) => fixes.stream;

  @override
  Future<LocationFix?> currentPosition() async => null;

  @override
  Future<LocationFix?> lastKnownPosition() async => null;

  @override
  Future<bool> openApplicationSettings() async => false;

  @override
  void dispose() => fixes.close();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('a cached first fix cannot create a phantom line', () async {
    final database = AppDatabase(
      fileName: 'record_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await database.open();
    addTearDown(database.close);

    final locationService = _FakeLocationService();
    final controller = RecordController(
      locationService: locationService,
      backgroundLocationService: const NoopBackgroundLocationService(),
      activityRepository: ActivityRepository(database),
      gearRepository: GearRepository(database),
      segmentEffortService: SegmentEffortService(SegmentRepository(database)),
    );
    addTearDown(controller.dispose);

    await controller.start(allowBackground: false);

    final start = DateTime.now();

    // A plausible-looking first fix (as if Android refreshed the timestamp
    // of its cached last-known location).
    locationService.fixes.add(
      LocationFix(
        latitude: 0,
        longitude: 0,
        accuracyMeters: 5,
        timestamp: start,
      ),
    );
    await pumpEventQueue();

    // The real start is 1.4 km away just two seconds later: the buffered fix
    // is stale and must not become the first track point.
    locationService.fixes.add(
      LocationFix(
        latitude: 0.009,
        longitude: 0.009,
        accuracyMeters: 5,
        timestamp: start.add(const Duration(seconds: 2)),
      ),
    );
    await pumpEventQueue();

    // A normal next sample ~47 m further along confirms the real start.
    locationService.fixes.add(
      LocationFix(
        latitude: 0.0093,
        longitude: 0.0093,
        accuracyMeters: 5,
        timestamp: start.add(const Duration(seconds: 4)),
      ),
    );
    await pumpEventQueue();

    expect(controller.points, hasLength(2));
    expect(controller.distanceMeters, closeTo(47, 3));
    expect(controller.points.first.latitude, closeTo(0.009, 1e-9));

    controller.stop();
  });

  test('auto-pause pauses after standstill and resumes on movement', () async {
    final database = AppDatabase(
      fileName: 'record_autopause_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await database.open();
    addTearDown(database.close);

    final locationService = _FakeLocationService();
    final controller = RecordController(
      locationService: locationService,
      backgroundLocationService: const NoopBackgroundLocationService(),
      activityRepository: ActivityRepository(database),
      gearRepository: GearRepository(database),
      segmentEffortService: SegmentEffortService(SegmentRepository(database)),
    );
    addTearDown(controller.dispose);

    await controller.start(allowBackground: false, autoPause: true);

    final t0 = DateTime.now();

    // Initial fixes to establish track
    locationService.fixes.add(
      LocationFix(
        latitude: 0.0,
        longitude: 0.0,
        accuracyMeters: 5,
        speedMps: 4.0,
        timestamp: t0,
      ),
    );
    await pumpEventQueue();

    locationService.fixes.add(
      LocationFix(
        latitude: 0.0003,
        longitude: 0.0,
        accuracyMeters: 5,
        speedMps: 4.0,
        timestamp: t0.add(const Duration(seconds: 2)),
      ),
    );
    await pumpEventQueue();

    expect(controller.isRecording, isTrue);
    expect(controller.isPaused, isFalse);
    expect(controller.points, hasLength(2));

    // Standstill starts at t0 + 5s
    locationService.fixes.add(
      LocationFix(
        latitude: 0.0003,
        longitude: 0.0,
        accuracyMeters: 5,
        speedMps: 0.0,
        timestamp: t0.add(const Duration(seconds: 5)),
      ),
    );
    await pumpEventQueue();
    expect(controller.isRecording, isTrue);
    expect(controller.isPaused, isFalse);

    // Standstill continues for 21 seconds (t0 + 26s > 20s delay)
    locationService.fixes.add(
      LocationFix(
        latitude: 0.0003,
        longitude: 0.0,
        accuracyMeters: 5,
        speedMps: 0.0,
        timestamp: t0.add(const Duration(seconds: 26)),
      ),
    );
    await pumpEventQueue();

    expect(controller.isPaused, isTrue);
    expect(controller.isAutoPaused, isTrue);

    // Movement resumes at t0 + 35s
    locationService.fixes.add(
      LocationFix(
        latitude: 0.0006,
        longitude: 0.0,
        accuracyMeters: 5,
        speedMps: 3.5,
        timestamp: t0.add(const Duration(seconds: 35)),
      ),
    );
    await pumpEventQueue();

    expect(controller.isRecording, isTrue);
    expect(controller.isPaused, isFalse);
    expect(controller.isAutoPaused, isFalse);
    expect(controller.points, hasLength(3));

    controller.stop();
  });

  test('manual pause does not auto-resume on movement', () async {
    final database = AppDatabase(
      fileName: 'record_manualpause_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await database.open();
    addTearDown(database.close);

    final locationService = _FakeLocationService();
    final controller = RecordController(
      locationService: locationService,
      backgroundLocationService: const NoopBackgroundLocationService(),
      activityRepository: ActivityRepository(database),
      gearRepository: GearRepository(database),
      segmentEffortService: SegmentEffortService(SegmentRepository(database)),
    );
    addTearDown(controller.dispose);

    await controller.start(allowBackground: false, autoPause: true);

    final t0 = DateTime.now();

    locationService.fixes.add(
      LocationFix(
        latitude: 0.0,
        longitude: 0.0,
        accuracyMeters: 5,
        timestamp: t0,
      ),
    );
    await pumpEventQueue();

    locationService.fixes.add(
      LocationFix(
        latitude: 0.0003,
        longitude: 0.0,
        accuracyMeters: 5,
        timestamp: t0.add(const Duration(seconds: 2)),
      ),
    );
    await pumpEventQueue();

    // User explicitly taps pause
    controller.pause();
    expect(controller.isPaused, isTrue);
    expect(controller.isAutoPaused, isFalse);

    // Movement fix arrives
    locationService.fixes.add(
      LocationFix(
        latitude: 0.0007,
        longitude: 0.0,
        accuracyMeters: 5,
        speedMps: 4.0,
        timestamp: t0.add(const Duration(seconds: 10)),
      ),
    );
    await pumpEventQueue();

    // Still paused because it was a manual pause
    expect(controller.isPaused, isTrue);
    expect(controller.isAutoPaused, isFalse);

    controller.stop();
  });

  test('moving rider with zero GPS-reported speed does not trigger auto-pause', () async {
    final database = AppDatabase(
      fileName: 'record_impliedspeed_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await database.open();
    addTearDown(database.close);

    final locationService = _FakeLocationService();
    final controller = RecordController(
      locationService: locationService,
      backgroundLocationService: const NoopBackgroundLocationService(),
      activityRepository: ActivityRepository(database),
      gearRepository: GearRepository(database),
      segmentEffortService: SegmentEffortService(SegmentRepository(database)),
    );
    addTearDown(controller.dispose);

    await controller.start(allowBackground: false, autoPause: true);

    final t0 = DateTime.now();

    // Initial fixes with speedMps = 0, but distance moving
    locationService.fixes.add(
      LocationFix(
        latitude: 0.0,
        longitude: 0.0,
        accuracyMeters: 5,
        speedMps: 0.0,
        timestamp: t0,
      ),
    );
    await pumpEventQueue();

    locationService.fixes.add(
      LocationFix(
        latitude: 0.0002,
        longitude: 0.0,
        accuracyMeters: 5,
        speedMps: 0.0,
        timestamp: t0.add(const Duration(seconds: 5)),
      ),
    );
    await pumpEventQueue();

    // Fixes keep moving ~22m every 5 seconds (implied speed ~4.4 m/s) with speedMps = 0
    for (var i = 1; i <= 6; i++) {
      locationService.fixes.add(
        LocationFix(
          latitude: 0.0002 + i * 0.0002,
          longitude: 0.0,
          accuracyMeters: 5,
          speedMps: 0.0,
          timestamp: t0.add(Duration(seconds: 5 + i * 5)),
        ),
      );
      await pumpEventQueue();
    }

    // After 35 total seconds, rider was continuously moving: should NOT be auto-paused
    expect(controller.isRecording, isTrue);
    expect(controller.isPaused, isFalse);

    controller.stop();
  });
}
