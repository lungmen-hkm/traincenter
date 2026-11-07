import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:traincenter/core/db/app_database.dart';
import 'package:traincenter/data/models/activity.dart';
import 'package:traincenter/data/models/segment.dart';
import 'package:traincenter/data/models/segment_effort.dart';
import 'package:traincenter/data/models/track_point.dart';
import 'package:traincenter/data/repositories/activity_repository.dart';
import 'package:traincenter/data/repositories/gear_repository.dart';
import 'package:traincenter/data/repositories/segment_repository.dart';
import 'package:traincenter/domain/services/segment_matcher.dart';
import 'package:traincenter/features/activities/activities_controller.dart';
import 'package:traincenter/features/segments/segments_controller.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test(
    'the segments controller loads stored efforts with the segments',
    () async {
      final database = AppDatabase(
        fileName: 'segments_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      await database.open();
      addTearDown(database.close);

      final activityRepository = ActivityRepository(database);
      final now = DateTime.now();
      final activityId = await activityRepository.insertActivity(
        Activity(
          title: 'Test ride',
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 5)),
          distanceMeters: 1000,
          movingTimeMs: 300000,
          elapsedTimeMs: 310000,
          avgSpeedMps: 3.3,
          maxSpeedMps: 8,
          elevationGainMeters: 0,
          createdAt: now,
        ),
        const <TrackPoint>[],
      );

      final repository = SegmentRepository(database);
      final segmentId = await repository.insertSegment(
        Segment(
          name: 'Test segment',
          activityId: activityId,
          startLatitude: -8.549236,
          startLongitude: 116.1509175,
          endLatitude: -8.54344,
          endLongitude: 116.1567218,
          distanceMeters: 907,
          createdAt: now,
        ),
      );
      await repository.insertEffort(
        SegmentEffort(
          segmentId: segmentId,
          activityId: activityId,
          timeMs: 80175,
          avgSpeedMps: 11.31,
          isPersonalBest: true,
          achievedAt: now,
        ),
      );

      final controller = SegmentsController(repository);
      await controller.load();

      expect(controller.segments, hasLength(1));
      expect(controller.effortsFor(segmentId), hasLength(1));
      expect(controller.personalBest(segmentId)?.timeMs, 80175);
      expect(controller.personalBest(segmentId)?.isPersonalBest, isTrue);
    },
  );

  test('efforts are grouped per segment, fastest first', () async {
    final database = AppDatabase(
      fileName: 'segments_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await database.open();
    addTearDown(database.close);

    final activityRepository = ActivityRepository(database);
    final now = DateTime.now();
    final activityId = await activityRepository.insertActivity(
      Activity(
        title: 'Grouping ride',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 5)),
        distanceMeters: 1000,
        movingTimeMs: 300000,
        elapsedTimeMs: 310000,
        avgSpeedMps: 3.3,
        maxSpeedMps: 8,
        elevationGainMeters: 0,
        createdAt: now,
      ),
      const <TrackPoint>[],
    );

    final repository = SegmentRepository(database);

    Segment segment(String name) => Segment(
      name: name,
      activityId: activityId,
      startLatitude: -8.549236,
      startLongitude: 116.1509175,
      endLatitude: -8.54344,
      endLongitude: 116.1567218,
      distanceMeters: 907,
      createdAt: now,
    );

    final firstId = await repository.insertSegment(segment('First'));
    final secondId = await repository.insertSegment(segment('Second'));

    Future<void> addEffort(int segmentId, int timeMs) {
      return repository.insertEffort(
        SegmentEffort(
          segmentId: segmentId,
          activityId: activityId,
          timeMs: timeMs,
          avgSpeedMps: 10,
          achievedAt: now,
        ),
      );
    }

    // Insert the fastest effort of the first segment last: the ordering is
    // applied by the query, not by the insertion order.
    await addEffort(firstId, 110000);
    await addEffort(secondId, 90000);
    await addEffort(firstId, 80000);

    final grouped = await repository.allEffortsBySegment();
    expect(grouped[firstId]!.map((effort) => effort.timeMs), <int>[
      80000,
      110000,
    ]);
    expect(grouped[secondId]!.map((effort) => effort.timeMs), <int>[90000]);

    final controller = SegmentsController(repository);
    await controller.load();
    expect(controller.personalBest(firstId)?.timeMs, 80000);
    expect(controller.personalBest(secondId)?.timeMs, 90000);
  });

  test('a slower pass is not a personal best', () {
    final now = DateTime.now();
    final segment = Segment(
      name: 'Diagonal',
      startLatitude: -8.549236,
      startLongitude: 116.1509175,
      endLatitude: -8.54344,
      endLongitude: 116.1567218,
      distanceMeters: 907,
      createdAt: now,
    );

    // 31 samples on a straight line between the endpoints, 3 seconds apart.
    final points = <TrackPoint>[
      for (var i = 0; i <= 30; i++)
        TrackPoint(
          seq: i,
          latitude: -8.549236 + (-8.54344 + 8.549236) * i / 30,
          longitude: 116.1509175 + (116.1567218 - 116.1509175) * i / 30,
          timestamp: now.add(Duration(seconds: i * 3)),
        ),
    ];

    final slower = SegmentMatcher.matchSegment(
      segment: segment,
      points: points,
      previousBestTimeMs: 60000,
    );
    expect(slower, isNotNull);
    expect(slower!.isPersonalBest, isFalse);
    expect(slower.timeMs, closeTo(90000, 1000));

    final faster = SegmentMatcher.matchSegment(
      segment: segment,
      points: points,
      previousBestTimeMs: 120000,
    );
    expect(faster, isNotNull);
    expect(faster!.isPersonalBest, isTrue);
  });

  test('deleting the PR activity promotes the next fastest effort', () async {
    final database = AppDatabase(
      fileName: 'segments_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await database.open();
    addTearDown(database.close);

    final now = DateTime.now();
    final activityRepository = ActivityRepository(database);
    final gearRepository = GearRepository(database);
    final segmentRepository = SegmentRepository(database);

    Future<int> insertActivity(String title) {
      return activityRepository.insertActivity(
        Activity(
          title: title,
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 2)),
          distanceMeters: 1000,
          movingTimeMs: 120000,
          elapsedTimeMs: 125000,
          avgSpeedMps: 8.3,
          maxSpeedMps: 10,
          elevationGainMeters: 0,
          createdAt: now,
        ),
        const <TrackPoint>[],
      );
    }

    final fastActivityId = await insertActivity('Fast ride');
    final slowActivityId = await insertActivity('Slow ride');

    final segmentId = await segmentRepository.insertSegment(
      Segment(
        name: 'PR segment',
        activityId: fastActivityId,
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
        activityId: fastActivityId,
        timeMs: 80000,
        avgSpeedMps: 11.3,
        isPersonalBest: true,
        achievedAt: now,
      ),
    );
    await segmentRepository.insertEffort(
      SegmentEffort(
        segmentId: segmentId,
        activityId: slowActivityId,
        timeMs: 110000,
        avgSpeedMps: 8.2,
        isPersonalBest: false,
        achievedAt: now,
      ),
    );

    final fastActivity = await activityRepository.findById(fastActivityId);
    expect(fastActivity, isNotNull);

    final controller = ActivitiesController(
      activityRepository,
      gearRepository,
      segmentRepository,
    );
    await controller.delete(fastActivity!);

    final remaining = await segmentRepository.effortsFor(segmentId);
    expect(remaining, hasLength(1));
    expect(remaining.single.activityId, slowActivityId);
    expect(remaining.single.isPersonalBest, isTrue);
    expect(remaining.single.timeMs, 110000);
  });
}
