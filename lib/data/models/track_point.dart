/// A single GPS sample belonging to an activity.
class TrackPoint {
  /// Database identifier. `null` for points that have not been persisted.
  final int? id;

  /// Owning activity.
  final int? activityId;

  /// Monotonic sequence number preserving the recording order.
  final int seq;

  /// Latitude in degrees (WGS84).
  final double latitude;

  /// Longitude in degrees (WGS84).
  final double longitude;

  /// Altitude in metres above the WGS84 ellipsoid, when available.
  final double? altitude;

  /// Instantaneous speed in metres per second, when available.
  final double? speed;

  /// Horizontal accuracy radius in metres, when available.
  final double? accuracy;

  /// Timestamp of the sample.
  final DateTime timestamp;

  const TrackPoint({
    this.id,
    this.activityId,
    required this.seq,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.accuracy,
    required this.timestamp,
  });

  /// Builds a track point from a database row.
  factory TrackPoint.fromMap(Map<String, Object?> map) {
    return TrackPoint(
      id: map['id'] as int?,
      activityId: map['activity_id'] as int?,
      seq: (map['seq'] as int?) ?? 0,
      latitude: (map['lat'] as num?)?.toDouble() ?? 0,
      longitude: (map['lng'] as num?)?.toDouble() ?? 0,
      altitude: (map['altitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as int?) ?? 0),
    );
  }

  /// Converts the track point into a database row.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'activity_id': activityId,
        'seq': seq,
        'lat': latitude,
        'lng': longitude,
        'altitude': altitude,
        'speed': speed,
        'accuracy': accuracy,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  /// Returns a copy with the given fields replaced.
  TrackPoint copyWith({
    int? id,
    int? activityId,
    int? seq,
    double? latitude,
    double? longitude,
    double? altitude,
    double? speed,
    double? accuracy,
    DateTime? timestamp,
  }) {
    return TrackPoint(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      seq: seq ?? this.seq,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
