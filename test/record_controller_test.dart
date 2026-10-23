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
}
