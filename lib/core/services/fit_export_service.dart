import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fit_sdk/fit_sdk.dart' as fit;

import '../../data/models/activity.dart';
import '../../data/models/gear.dart';
import '../../data/models/track_point.dart';
import '../utils/geo_utils.dart';

/// Encodes a recorded activity as a Garmin-compatible FIT file.
///
/// The encoder is intentionally independent of Flutter and the database so it
/// can be unit-tested with plain Dart values. The file contains the activity
/// summary, one lap, timer events and one record per GPS sample.
class FitExportService {
  /// Creates a FIT export service.
  const FitExportService();

  /// Seconds between the Unix epoch and the FIT epoch (1989-12-31 UTC).
  static const int _fitEpochOffsetSeconds = 631065600;

  /// Number of FIT semicircles in one degree.
  static const double _semicirclesPerDegree = 2147483648.0 / 180.0;

  /// Product identifier used for files written by TrainCenter.
  static const int _productId = 1;

  /// Stable serial number derived from "TRC".
  static const int _serialNumber = 0x545243;

  /// Product name written into the FIT file id message.
  static const String _productName = 'TrainCenter';

  /// Encodes [activity] and its GPS [points] into FIT bytes.
  ///
  /// [gearType] determines the FIT sport: bicycles are encoded as cycling,
  /// shoes as running and an unknown gear as the generic sport. The activity
  /// summary is always exported, even when the track has no GPS samples.
  Uint8List encodeActivity({
    required Activity activity,
    required List<TrackPoint> points,
    GearType? gearType,
  }) {
    final encoder = fit.Encode();
    encoder.open();

    final sport = _sportFor(gearType);
    final subSport = fit.SubSport.generic;
    final validPoints = points
        .where((point) => _hasValidPosition(point.latitude, point.longitude))
        .toList(growable: false);
    final firstPoint = validPoints.isEmpty ? null : validPoints.first;
    final lastPoint = validPoints.isEmpty ? null : validPoints.last;

    _writeFileId(encoder, activity);
    _writeFileCreator(encoder);
    _writeEvent(encoder, activity.startedAt, fit.EventType.start);

    final records = _buildRecords(points);
    if (records.isNotEmpty) {
      // Every record sets the same fields, so the first definition can be
      // reused for all of them. Missing optional values are written as the
      // FIT invalid sentinel.
      final definition = fit.MesgDefinition.fromMesg(records.first);
      encoder.writeMesgDefinition(definition);
      for (final record in records) {
        encoder.writeMesg(record, definition);
      }
    }

    _writeEvent(encoder, activity.endedAt, fit.EventType.stop);
    _writeLap(
      encoder,
      activity: activity,
      sport: sport,
      subSport: subSport,
      firstPoint: firstPoint,
      lastPoint: lastPoint,
    );
    _writeSession(
      encoder,
      activity: activity,
      sport: sport,
      subSport: subSport,
      firstPoint: firstPoint,
      lastPoint: lastPoint,
    );
    _writeActivity(encoder, activity);

    return encoder.close();
  }

  /// Writes the required file id message.
  void _writeFileId(fit.Encode encoder, Activity activity) {
    final message = fit.FileIdMesg()
      ..setFieldValue(fit.FileIdMesg.fieldType, fit.File.activity)
      ..setFieldValue(
        fit.FileIdMesg.fieldManufacturer,
        fit.Manufacturer.development,
      )
      ..setFieldValue(fit.FileIdMesg.fieldProduct, _productId)
      ..setFieldValue(fit.FileIdMesg.fieldSerialNumber, _serialNumber)
      ..setFieldValue(
        fit.FileIdMesg.fieldTimeCreated,
        _fitTimestamp(activity.endedAt),
      )
      ..setFieldValue(fit.FileIdMesg.fieldProductName, _productName);
    _writeMessage(encoder, message);
  }

  /// Writes the optional file creator message.
  void _writeFileCreator(fit.Encode encoder) {
    final message = fit.FileCreatorMesg()
      ..setFieldValue(fit.FileCreatorMesg.fieldSoftwareVersion, 100)
      ..setFieldValue(fit.FileCreatorMesg.fieldHardwareVersion, 1);
    _writeMessage(encoder, message);
  }

  /// Writes a timer start or stop event.
  void _writeEvent(fit.Encode encoder, DateTime timestamp, int eventType) {
    final message = fit.EventMesg()
      ..setFieldValue(fit.EventMesg.fieldTimestamp, _fitTimestamp(timestamp))
      ..setFieldValue(fit.EventMesg.fieldEvent, fit.Event.timer)
      ..setFieldValue(fit.EventMesg.fieldEventType, eventType)
      ..setFieldValue(fit.EventMesg.fieldEventGroup, 0);
    _writeMessage(encoder, message);
  }

  /// Builds one FIT record message per GPS sample.
  ///
  /// The distance is accumulated from the valid GPS positions so consumers
  /// can draw a distance/time graph even when the device did not provide a
  /// per-sample distance. Invalid positions are written as FIT invalid values
  /// instead of being silently removed, preserving the sample timestamps.
  List<fit.RecordMesg> _buildRecords(List<TrackPoint> points) {
    final records = <fit.RecordMesg>[];
    var cumulativeDistance = 0.0;
    TrackPoint? previousValidPoint;
    int? previousTimestamp;

    for (final point in points) {
      final hasPosition = _hasValidPosition(point.latitude, point.longitude);
      if (hasPosition && previousValidPoint != null) {
        cumulativeDistance += GeoUtils.distanceMeters(
          lat1: previousValidPoint.latitude,
          lon1: previousValidPoint.longitude,
          lat2: point.latitude,
          lon2: point.longitude,
        );
      }
      if (hasPosition) previousValidPoint = point;

      var timestamp = _fitTimestamp(point.timestamp);
      if (previousTimestamp != null && timestamp < previousTimestamp) {
        timestamp = previousTimestamp;
      }
      previousTimestamp = timestamp;

      final altitude = _validAltitude(point.altitude);
      final speed = _validSpeed(point.speed);
      final message = fit.RecordMesg()
        ..setFieldValue(fit.RecordMesg.fieldTimestamp, timestamp)
        ..setFieldValue(
          fit.RecordMesg.fieldPositionLat,
          hasPosition ? _semicircles(point.latitude) : null,
        )
        ..setFieldValue(
          fit.RecordMesg.fieldPositionLong,
          hasPosition ? _semicircles(point.longitude) : null,
        )
        ..setFieldValue(fit.RecordMesg.fieldAltitude, altitude)
        ..setFieldValue(fit.RecordMesg.fieldEnhancedAltitude, altitude)
        ..setFieldValue(fit.RecordMesg.fieldDistance, cumulativeDistance)
        ..setFieldValue(fit.RecordMesg.fieldSpeed, speed)
        ..setFieldValue(fit.RecordMesg.fieldEnhancedSpeed, speed);
      records.add(message);
    }

    return records;
  }

  /// Writes the single lap summary.
  void _writeLap(
    fit.Encode encoder, {
    required Activity activity,
    required int sport,
    required int subSport,
    required TrackPoint? firstPoint,
    required TrackPoint? lastPoint,
  }) {
    final message = fit.LapMesg()
      ..setFieldValue(fit.LapMesg.fieldMessageIndex, 0)
      ..setFieldValue(
        fit.LapMesg.fieldTimestamp,
        _fitTimestamp(activity.endedAt),
      )
      ..setFieldValue(fit.LapMesg.fieldEvent, fit.Event.lap)
      ..setFieldValue(fit.LapMesg.fieldEventType, fit.EventType.stop)
      ..setFieldValue(
        fit.LapMesg.fieldStartTime,
        _fitTimestamp(activity.startedAt),
      )
      ..setFieldValue(fit.LapMesg.fieldSport, sport)
      ..setFieldValue(fit.LapMesg.fieldSubSport, subSport)
      ..setFieldValue(
        fit.LapMesg.fieldTotalElapsedTime,
        _seconds(activity.elapsedTimeMs),
      )
      ..setFieldValue(
        fit.LapMesg.fieldTotalTimerTime,
        _seconds(activity.movingTimeMs),
      )
      ..setFieldValue(
        fit.LapMesg.fieldTotalMovingTime,
        _seconds(activity.movingTimeMs),
      )
      ..setFieldValue(fit.LapMesg.fieldTotalDistance, _distance(activity))
      ..setFieldValue(fit.LapMesg.fieldAvgSpeed, _speed(activity.avgSpeedMps))
      ..setFieldValue(fit.LapMesg.fieldMaxSpeed, _speed(activity.maxSpeedMps))
      ..setFieldValue(
        fit.LapMesg.fieldEnhancedAvgSpeed,
        _speed(activity.avgSpeedMps),
      )
      ..setFieldValue(
        fit.LapMesg.fieldEnhancedMaxSpeed,
        _speed(activity.maxSpeedMps),
      )
      ..setFieldValue(fit.LapMesg.fieldTotalAscent, _ascent(activity))
      ..setFieldValue(fit.LapMesg.fieldLapTrigger, fit.LapTrigger.sessionEnd);

    if (firstPoint != null) {
      message
        ..setFieldValue(
          fit.LapMesg.fieldStartPositionLat,
          _semicircles(firstPoint.latitude),
        )
        ..setFieldValue(
          fit.LapMesg.fieldStartPositionLong,
          _semicircles(firstPoint.longitude),
        );
    }
    if (lastPoint != null) {
      message
        ..setFieldValue(
          fit.LapMesg.fieldEndPositionLat,
          _semicircles(lastPoint.latitude),
        )
        ..setFieldValue(
          fit.LapMesg.fieldEndPositionLong,
          _semicircles(lastPoint.longitude),
        );
    }

    _writeMessage(encoder, message);
  }

  /// Writes the session summary.
  void _writeSession(
    fit.Encode encoder, {
    required Activity activity,
    required int sport,
    required int subSport,
    required TrackPoint? firstPoint,
    required TrackPoint? lastPoint,
  }) {
    final message = fit.SessionMesg()
      ..setFieldValue(fit.SessionMesg.fieldMessageIndex, 0)
      ..setFieldValue(
        fit.SessionMesg.fieldTimestamp,
        _fitTimestamp(activity.endedAt),
      )
      ..setFieldValue(fit.SessionMesg.fieldEvent, fit.Event.session)
      ..setFieldValue(fit.SessionMesg.fieldEventType, fit.EventType.stop)
      ..setFieldValue(
        fit.SessionMesg.fieldStartTime,
        _fitTimestamp(activity.startedAt),
      )
      ..setFieldValue(fit.SessionMesg.fieldSport, sport)
      ..setFieldValue(fit.SessionMesg.fieldSubSport, subSport)
      ..setFieldValue(
        fit.SessionMesg.fieldTotalElapsedTime,
        _seconds(activity.elapsedTimeMs),
      )
      ..setFieldValue(
        fit.SessionMesg.fieldTotalTimerTime,
        _seconds(activity.movingTimeMs),
      )
      ..setFieldValue(
        fit.SessionMesg.fieldTotalMovingTime,
        _seconds(activity.movingTimeMs),
      )
      ..setFieldValue(fit.SessionMesg.fieldTotalDistance, _distance(activity))
      ..setFieldValue(
        fit.SessionMesg.fieldAvgSpeed,
        _speed(activity.avgSpeedMps),
      )
      ..setFieldValue(
        fit.SessionMesg.fieldMaxSpeed,
        _speed(activity.maxSpeedMps),
      )
      ..setFieldValue(
        fit.SessionMesg.fieldEnhancedAvgSpeed,
        _speed(activity.avgSpeedMps),
      )
      ..setFieldValue(
        fit.SessionMesg.fieldEnhancedMaxSpeed,
        _speed(activity.maxSpeedMps),
      )
      ..setFieldValue(fit.SessionMesg.fieldTotalAscent, _ascent(activity))
      ..setFieldValue(fit.SessionMesg.fieldFirstLapIndex, 0)
      ..setFieldValue(fit.SessionMesg.fieldNumLaps, 1)
      ..setFieldValue(
        fit.SessionMesg.fieldTrigger,
        fit.SessionTrigger.activityEnd,
      );

    if (firstPoint != null) {
      message
        ..setFieldValue(
          fit.SessionMesg.fieldStartPositionLat,
          _semicircles(firstPoint.latitude),
        )
        ..setFieldValue(
          fit.SessionMesg.fieldStartPositionLong,
          _semicircles(firstPoint.longitude),
        );
    }
    if (lastPoint != null) {
      message
        ..setFieldValue(
          fit.SessionMesg.fieldEndPositionLat,
          _semicircles(lastPoint.latitude),
        )
        ..setFieldValue(
          fit.SessionMesg.fieldEndPositionLong,
          _semicircles(lastPoint.longitude),
        );
    }

    _writeMessage(encoder, message);
  }

  /// Writes the final activity message.
  void _writeActivity(fit.Encode encoder, Activity activity) {
    final message = fit.ActivityMesg()
      ..setFieldValue(
        fit.ActivityMesg.fieldTimestamp,
        _fitTimestamp(activity.endedAt),
      )
      ..setFieldValue(
        fit.ActivityMesg.fieldTotalTimerTime,
        _seconds(activity.movingTimeMs),
      )
      ..setFieldValue(fit.ActivityMesg.fieldNumSessions, 1)
      ..setFieldValue(fit.ActivityMesg.fieldType, fit.Activity.manual)
      ..setFieldValue(fit.ActivityMesg.fieldEvent, fit.Event.activity)
      ..setFieldValue(fit.ActivityMesg.fieldEventType, fit.EventType.stop);
    _writeMessage(encoder, message);
  }

  /// Writes a message and its definition.
  void _writeMessage(fit.Encode encoder, fit.Mesg message) {
    encoder.writeMesgDefinition(fit.MesgDefinition.fromMesg(message));
    encoder.writeMesg(message);
  }

  /// Maps the gear type to a FIT sport.
  int _sportFor(GearType? gearType) => switch (gearType) {
    GearType.bicycle => fit.Sport.cycling,
    GearType.shoe => fit.Sport.running,
    null => fit.Sport.generic,
  };

  /// Converts a [DateTime] into FIT seconds since 1989-12-31 UTC.
  int _fitTimestamp(DateTime value) {
    final seconds =
        value.toUtc().millisecondsSinceEpoch ~/ 1000 - _fitEpochOffsetSeconds;
    return math.max(0, seconds);
  }

  /// Converts milliseconds to seconds for FIT's scaled time fields.
  double _seconds(int milliseconds) => milliseconds / 1000.0;

  /// Returns the activity distance clamped to the FIT uint32 range.
  double _distance(Activity activity) => activity.distanceMeters.isFinite
      ? math.max(0, activity.distanceMeters)
      : 0;

  /// Returns the elevation gain clamped to the FIT uint16 range.
  int _ascent(Activity activity) {
    if (!activity.elevationGainMeters.isFinite) return 0;
    return activity.elevationGainMeters.round().clamp(0, 65535);
  }

  /// Returns a finite, non-negative speed or `null` when it cannot be encoded.
  double? _speed(double value) {
    if (!value.isFinite || value < 0) return null;
    // The basic FIT speed field is a uint16 in millimetres per second.
    return value.clamp(0.0, 65.5);
  }

  /// Returns an altitude that fits the basic FIT altitude field.
  double? _validAltitude(double? value) {
    if (value == null || !value.isFinite) return null;
    if (value < -500 || value > 12500) return null;
    return value;
  }

  /// Returns a speed that fits the basic FIT record speed field.
  double? _validSpeed(double? value) {
    if (value == null || !value.isFinite || value < 0) return null;
    if (value > 65.535) return null;
    return value;
  }

  /// Whether a coordinate can be encoded as a FIT position.
  bool _hasValidPosition(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  /// Converts degrees to FIT semicircles.
  int _semicircles(double degrees) => (degrees * _semicirclesPerDegree).round();
}
