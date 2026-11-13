import 'dart:typed_data';

import 'package:fit_sdk/fit_sdk.dart' as fit;
import 'package:flutter_test/flutter_test.dart';
import 'package:traincenter/core/services/fit_export_service.dart';
import 'package:traincenter/data/models/activity.dart';
import 'package:traincenter/data/models/gear.dart';
import 'package:traincenter/data/models/track_point.dart';

void main() {
  const encoder = FitExportService();
  final startedAt = DateTime.utc(2026, 11, 13, 8, 30);
  final endedAt = startedAt.add(const Duration(minutes: 30));

  Activity buildActivity({int? gearId}) {
    return Activity(
      id: 7,
      title: 'Morning ride',
      gearId: gearId,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: 15000,
      movingTimeMs: 25 * 60 * 1000,
      elapsedTimeMs: 30 * 60 * 1000,
      avgSpeedMps: 10,
      maxSpeedMps: 14.5,
      elevationGainMeters: 210,
      createdAt: startedAt,
    );
  }

  List<TrackPoint> buildPoints() {
    return <TrackPoint>[
      TrackPoint(
        seq: 0,
        latitude: 48.8500,
        longitude: 2.3500,
        altitude: 35,
        speed: 8.5,
        timestamp: startedAt,
      ),
      TrackPoint(
        seq: 1,
        latitude: 48.8510,
        longitude: 2.3510,
        altitude: 37,
        speed: 10.0,
        timestamp: startedAt.add(const Duration(seconds: 10)),
      ),
      TrackPoint(
        seq: 2,
        latitude: 48.8520,
        longitude: 2.3520,
        altitude: 39,
        speed: 11.0,
        timestamp: startedAt.add(const Duration(seconds: 20)),
      ),
    ];
  }

  List<fit.Mesg> decode(Uint8List bytes) {
    final messages = <fit.Mesg>[];
    final decoder = fit.Decode()..onMesg = messages.add;
    decoder.read(bytes);
    return messages;
  }

  fit.FileIdMesg fileId(List<fit.Mesg> messages) => fit.FileIdMesg.fromMesg(
    messages.singleWhere((message) => message.num == fit.MesgNum.fileId),
  );

  fit.SessionMesg session(List<fit.Mesg> messages) => fit.SessionMesg.fromMesg(
    messages.singleWhere((message) => message.num == fit.MesgNum.session),
  );

  fit.LapMesg lap(List<fit.Mesg> messages) => fit.LapMesg.fromMesg(
    messages.singleWhere((message) => message.num == fit.MesgNum.lap),
  );

  fit.ActivityMesg activity(List<fit.Mesg> messages) =>
      fit.ActivityMesg.fromMesg(
        messages.singleWhere((message) => message.num == fit.MesgNum.activity),
      );

  List<fit.RecordMesg> records(List<fit.Mesg> messages) => messages
      .where((message) => message.num == fit.MesgNum.record)
      .map(fit.RecordMesg.fromMesg)
      .toList(growable: false);

  double semicirclesToDegrees(int value) => value / (2147483648.0 / 180.0);

  test('encodes a bicycle activity with track, lap and session data', () {
    final bytes = encoder.encodeActivity(
      activity: buildActivity(gearId: 3),
      points: buildPoints(),
      gearType: GearType.bicycle,
    );

    final messages = decode(bytes);
    final fileIdMesg = fileId(messages);
    expect(fileIdMesg.getType(), fit.File.activity);
    expect(fileIdMesg.getManufacturer(), fit.Manufacturer.development);
    expect(fileIdMesg.getProductName(), 'TrainCenter');
    expect(fileIdMesg.getTimeCreated()!.toUtc(), endedAt);

    final sessionMesg = session(messages);
    expect(sessionMesg.getSport(), fit.Sport.cycling);
    expect(sessionMesg.getSubSport(), fit.SubSport.generic);
    expect(sessionMesg.getStartTime()!.toUtc(), startedAt);
    expect(sessionMesg.getTotalElapsedTime(), closeTo(1800, 0.001));
    expect(sessionMesg.getTotalTimerTime(), closeTo(1500, 0.001));
    expect(sessionMesg.getTotalMovingTime(), closeTo(1500, 0.001));
    expect(sessionMesg.getTotalDistance(), closeTo(15000, 0.001));
    expect(sessionMesg.getAvgSpeed(), closeTo(10, 0.001));
    expect(sessionMesg.getMaxSpeed(), closeTo(14.5, 0.001));
    expect(sessionMesg.getEnhancedAvgSpeed(), closeTo(10, 0.001));
    expect(sessionMesg.getEnhancedMaxSpeed(), closeTo(14.5, 0.001));
    expect(sessionMesg.getTotalAscent(), 210);
    expect(sessionMesg.getNumLaps(), 1);
    expect(sessionMesg.getFirstLapIndex(), 0);
    expect(
      semicirclesToDegrees(sessionMesg.getStartPositionLat()!),
      closeTo(48.8500, 0.000001),
    );
    expect(
      semicirclesToDegrees(sessionMesg.getEndPositionLong()!),
      closeTo(2.3520, 0.000001),
    );

    final lapMesg = lap(messages);
    expect(lapMesg.getSport(), fit.Sport.cycling);
    expect(lapMesg.getTotalDistance(), closeTo(15000, 0.001));
    expect(lapMesg.getAvgSpeed(), closeTo(10, 0.001));
    expect(lapMesg.getTotalAscent(), 210);

    final activityMesg = activity(messages);
    expect(activityMesg.getNumSessions(), 1);
    expect(activityMesg.getType(), fit.Activity.manual);
    expect(activityMesg.getTotalTimerTime(), closeTo(1500, 0.001));

    final recordMesgs = records(messages);
    expect(recordMesgs, hasLength(3));
    expect(recordMesgs.first.getTimestamp()!.toUtc(), startedAt);
    expect(recordMesgs.first.getDistance(), closeTo(0, 0.001));
    expect(recordMesgs.first.getAltitude(), closeTo(35, 0.001));
    expect(recordMesgs.first.getSpeed(), closeTo(8.5, 0.001));
    expect(recordMesgs[1].getDistance(), greaterThan(0));
    expect(
      semicirclesToDegrees(recordMesgs.first.getPositionLat()!),
      closeTo(48.8500, 0.000001),
    );

    final events = messages
        .where((message) => message.num == fit.MesgNum.event)
        .map(fit.EventMesg.fromMesg)
        .toList(growable: false);
    expect(events, hasLength(2));
    expect(events.first.getEvent(), fit.Event.timer);
    expect(events.first.getEventType(), fit.EventType.start);
    expect(events.last.getEventType(), fit.EventType.stop);
  });

  test('uses running for shoes and keeps the summary without GPS samples', () {
    final bytes = encoder.encodeActivity(
      activity: buildActivity(gearId: 4),
      points: const <TrackPoint>[],
      gearType: GearType.shoe,
    );

    final messages = decode(bytes);
    final sessionMesg = session(messages);
    expect(sessionMesg.getSport(), fit.Sport.running);
    expect(sessionMesg.getTotalDistance(), closeTo(15000, 0.001));
    expect(records(messages), isEmpty);
  });

  test('falls back to the generic sport when the activity has no gear', () {
    final bytes = encoder.encodeActivity(
      activity: buildActivity(),
      points: const <TrackPoint>[],
    );

    final messages = decode(bytes);
    expect(session(messages).getSport(), fit.Sport.generic);
    expect(lap(messages).getSport(), fit.Sport.generic);
  });

  test('writes invalid sentinels for missing optional record values', () {
    final bytes = encoder.encodeActivity(
      activity: buildActivity(gearId: 3),
      points: <TrackPoint>[
        TrackPoint(
          seq: 0,
          latitude: 48.8500,
          longitude: 2.3500,
          timestamp: startedAt,
        ),
      ],
      gearType: GearType.bicycle,
    );

    final record = records(decode(bytes)).single;
    expect(record.getAltitude(), isNull);
    expect(record.getSpeed(), isNull);
    expect(record.getDistance(), closeTo(0, 0.001));
  });
}
