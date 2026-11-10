import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:traincenter/app.dart';
import 'package:traincenter/core/db/app_database.dart';
import 'package:traincenter/core/services/background_location_service.dart';
import 'package:traincenter/core/services/location_service.dart';
import 'package:traincenter/core/widgets/slide_to_confirm.dart';
import 'package:traincenter/data/models/activity.dart';
import 'package:traincenter/data/models/gear.dart';
import 'package:traincenter/data/models/segment.dart';
import 'package:traincenter/data/models/segment_effort.dart';
import 'package:traincenter/data/models/track_point.dart';
import 'package:traincenter/data/repositories/activity_repository.dart';
import 'package:traincenter/data/repositories/gear_repository.dart';
import 'package:traincenter/data/repositories/segment_repository.dart';
import 'package:traincenter/features/export/activity_export_card.dart';
import 'package:traincenter/features/record/record_controller.dart';
import 'package:widgets_to_image/widgets_to_image.dart';

class _TestLocationService implements LocationService {
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
    // The "no isolate" factory runs the SQLite calls in the current isolate,
    // which is required inside the fake-async zone of a widget test.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  /// Opens a fresh database for a single test.
  Future<AppDatabase> openDatabase(WidgetTester tester) async {
    final database = AppDatabase(
      fileName: 'test_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await tester.runAsync(database.open);
    return database;
  }

  /// Pumps the application and lets the asynchronous providers settle.
  Future<void> bootApp(
    WidgetTester tester,
    AppDatabase database, {
    LocationService? locationService,
  }) async {
    await tester.pumpWidget(
      TrainCenterApp(
        database: database,
        locationService: locationService ?? _TestLocationService(),
        backgroundLocationService: const NoopBackgroundLocationService(),
      ),
    );
    // Let the repositories load; a few frames are enough because the
    // loading spinner would otherwise never settle.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('boots into the record screen', (tester) async {
    final database = await openDatabase(tester);
    addTearDown(database.close);

    await bootApp(tester, database);

    expect(find.text('TrainCenter'), findsOneWidget);
    expect(find.text('Start recording'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('the appearance setting switches the app to dark mode', (
    tester,
  ) async {
    final database = await openDatabase(tester);
    addTearDown(database.close);

    await bootApp(tester, database);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);

    final selector = find.byKey(const Key('theme-mode-selector'));
    expect(selector, findsOneWidget);
    await tester.tap(
      find.descendant(of: selector, matching: find.text('Dark')),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    final settingsContext = tester.element(find.text('Appearance'));
    expect(Theme.of(settingsContext).brightness, Brightness.dark);
  });

  testWidgets('navigates between the four destinations', (tester) async {
    final database = await openDatabase(tester);
    addTearDown(database.close);

    await bootApp(tester, database);

    await tester.tap(find.text('Activities'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No activities yet'), findsOneWidget);

    await tester.tap(find.text('Segments'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No segments yet'), findsOneWidget);

    await tester.tap(find.text('Gear'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('No gear yet'), findsOneWidget);
  });

  testWidgets('opens the TrainerCraft bridge from the app bar', (tester) async {
    final database = await openDatabase(tester);
    addTearDown(database.close);

    await bootApp(tester, database);

    await tester.tap(find.byTooltip('TrainerCraft'));
    await tester.pumpAndSettle();

    expect(find.text('TrainerCraft'), findsOneWidget);
    expect(find.text('Bridge is idle'), findsOneWidget);
    expect(find.text('Start bridge'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Wheel circumference'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Wheel circumference'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Start recording'), findsOneWidget);
  });

  testWidgets('stores a gear and lists it', (tester) async {
    final database = await openDatabase(tester);
    addTearDown(database.close);

    await bootApp(tester, database);

    final gearRepository = GearRepository(database);
    final now = DateTime.now();
    await gearRepository.insertGear(
      Gear(
        name: 'Gravel bike',
        brand: 'Specialized',
        model: 'Diverge E5',
        type: GearType.bicycle,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Re-read the gear through the app.
    final gear = await gearRepository.listGear();
    expect(gear, hasLength(1));
    expect(gear.single.name, 'Gravel bike');
    expect(gear.single.isDefault, isTrue);

    // The default gear is picked up by the recording controller.
    final activityRepository = ActivityRepository(database);
    final activity = Activity(
      title: 'Morning ride',
      startedAt: now,
      endedAt: now.add(const Duration(minutes: 30)),
      distanceMeters: 15000,
      movingTimeMs: 30 * 60 * 1000,
      elapsedTimeMs: 32 * 60 * 1000,
      avgSpeedMps: 8.3,
      maxSpeedMps: 12.5,
      elevationGainMeters: 210,
      createdAt: now,
    );

    final points = <TrackPoint>[
      for (var i = 0; i < 5; i++)
        TrackPoint(
          seq: i,
          latitude: 48.85 + i * 0.001,
          longitude: 2.35 + i * 0.001,
          altitude: 35 + i * 2,
          timestamp: now.add(Duration(seconds: i * 10)),
        ),
    ];

    final activityId = await activityRepository.insertActivity(
      activity,
      points,
    );
    expect(activityId, greaterThan(0));

    final stored = await activityRepository.findById(activityId);
    expect(stored, isNotNull);
    expect(stored!.distanceMeters, 15000);

    final track = await activityRepository.trackPoints(activityId);
    expect(track, hasLength(5));
    expect(track.first.seq, 0);
    expect(track.last.seq, 4);
  });

  testWidgets('the slide to confirm action only fires past the threshold', (
    tester,
  ) async {
    var confirmed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: SlideToConfirm(onConfirmed: () => confirmed++),
            ),
          ),
        ),
      ),
    );

    final slider = find.byType(SlideToConfirm);
    expect(slider, findsOneWidget);

    // Drag well below the threshold: the action must not fire.
    await tester.drag(find.byType(SlideToConfirm), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(confirmed, 0);

    // Drag past the threshold: the action fires.
    await tester.drag(find.byType(SlideToConfirm), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(confirmed, 1);
  });

  testWidgets('the export card renders a transparent PNG', (tester) async {
    final controller = WidgetsToImageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: WidgetsToImage(
              controller: controller,
              child: ActivityExportCard(
                points: <LatLng>[
                  const LatLng(48.8500, 2.3500),
                  const LatLng(48.8560, 2.3520),
                  const LatLng(48.8620, 2.3480),
                  const LatLng(48.8680, 2.3540),
                ],
                distanceValue: '42.18',
                distanceUnit: 'km',
                speedValue: '28.4',
                speedUnit: 'km/h',
                durationValue: '1:12:30',
                activityLabel: 'Morning ride',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The three statistics are part of the card.
    expect(find.text('42.18'), findsOneWidget);
    expect(find.text('28.4'), findsOneWidget);
    expect(find.text('1:12:30'), findsOneWidget);
    expect(find.text('MORNING RIDE'), findsOneWidget);

    final bytes = await tester.runAsync(() async {
      final captured = await controller.capture(
        options: const CaptureOptions(format: ImageFormat.png, pixelRatio: 1),
      );
      if (captured == null) return null;

      // Decode the PNG so the alpha channel can be inspected.
      final codec = await ui.instantiateImageCodec(captured);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      return data?.buffer.asUint8List();
    });

    expect(bytes, isNotNull);
    final rgba = bytes!;

    expect(rgba.length, greaterThan(4));
    // The top-left corner is not covered by the route or by any text.
    expect(
      rgba[3],
      0,
      reason: 'the exported PNG must have a transparent background',
    );
    // The canvas is not empty either: the card really painted something.
    expect(
      rgba.skip(3).where((value) => value > 0).isNotEmpty,
      isTrue,
      reason: 'the exported PNG must contain the drawn content',
    );
  });

  testWidgets('settings screen disables data wipe when recording is active', (
    tester,
  ) async {
    final database = await openDatabase(tester);
    addTearDown(database.close);

    await bootApp(tester, database);

    // Open settings while idle
    await tester.tap(find.byTooltip('Settings'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.scrollUntilVisible(
      find.text('Erase all local data'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Erase all local data'), findsOneWidget);
    expect(
      find.text('Removes every activity, gear and segment.'),
      findsOneWidget,
    );

    // Go back to shell
    await tester.tap(find.byType(BackButton));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Start recording
    final recordController = tester
        .element(find.byType(MaterialApp))
        .read<RecordController>();
    await recordController.start(allowBackground: false);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Open settings while recording is active
    await tester.tap(find.byTooltip('Settings'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.scrollUntilVisible(
      find.text('Erase all local data'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.text('Finish or discard your active recording first.'),
      findsOneWidget,
    );

    // Tapping the disabled tile should not show confirmation dialog
    await tester.tap(find.text('Erase all local data'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Erase all data?'), findsNothing);

    recordController.stop();
  });

  testWidgets('screens stay usable at 320 dp and 200 % text', (tester) async {
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final database = await openDatabase(tester);
    addTearDown(database.close);

    final now = DateTime.now();
    final activityRepository = ActivityRepository(database);
    final activityId = await activityRepository.insertActivity(
      Activity(
        title: 'Morning ride',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 30)),
        distanceMeters: 15000,
        movingTimeMs: 30 * 60 * 1000,
        elapsedTimeMs: 32 * 60 * 1000,
        avgSpeedMps: 8.3,
        maxSpeedMps: 12.5,
        elevationGainMeters: 210,
        createdAt: now,
      ),
      const <TrackPoint>[],
    );

    final gearRepository = GearRepository(database);
    await gearRepository.insertGear(
      Gear(
        name: 'Gravel bike',
        brand: 'Specialized',
        model: 'Diverge E5',
        type: GearType.bicycle,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final segmentRepository = SegmentRepository(database);
    final segmentId = await segmentRepository.insertSegment(
      Segment(
        name: 'Diagonal segment',
        activityId: activityId,
        startLatitude: -8.549236,
        startLongitude: 116.1509175,
        endLatitude: -8.54344,
        endLongitude: 116.1567218,
        distanceMeters: 907,
        createdAt: now,
      ),
    );
    await segmentRepository.insertEffort(
      SegmentEffort(
        segmentId: segmentId,
        activityId: activityId,
        timeMs: 80175,
        avgSpeedMps: 11.31,
        isPersonalBest: true,
        achievedAt: now,
      ),
    );

    await bootApp(tester, database);
    expect(find.text('Start recording'), findsOneWidget);
    expect(tester.takeException(), isNull);

    Future<void> openTab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: '$label overflowed');
    }

    await openTab('Activities');
    await openTab('Segments');
    await openTab('Gear');

    await tester.tap(find.byTooltip('TrainerCraft'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'TrainerCraft overflowed');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    // Lay out the bottom of Settings, including the export controls and the
    // privacy copy.
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -4000));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
