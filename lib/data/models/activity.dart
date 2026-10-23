/// A recorded activity (ride, run, ...).
class Activity {
  /// Database identifier. `null` for activities that have not been persisted.
  final int? id;

  /// Optional user supplied title.
  final String? title;

  /// Gear this activity was recorded with.
  final int? gearId;

  /// When the recording started.
  final DateTime startedAt;

  /// When the recording stopped.
  final DateTime endedAt;

  /// Total travelled distance (metres).
  final double distanceMeters;

  /// Time spent actually moving (milliseconds).
  final int movingTimeMs;

  /// Wall clock time between start and stop (milliseconds).
  final int elapsedTimeMs;

  /// Average moving speed (metres per second).
  final double avgSpeedMps;

  /// Highest instantaneous speed (metres per second).
  final double maxSpeedMps;

  /// Cumulative ascent (metres).
  final double elevationGainMeters;

  /// Optional free-form note.
  final String? note;

  /// Row creation timestamp.
  final DateTime createdAt;

  const Activity({
    this.id,
    this.title,
    this.gearId,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.movingTimeMs,
    required this.elapsedTimeMs,
    required this.avgSpeedMps,
    required this.maxSpeedMps,
    required this.elevationGainMeters,
    this.note,
    required this.createdAt,
  });

  /// Builds an activity from a database row.
  factory Activity.fromMap(Map<String, Object?> map) {
    return Activity(
      id: map['id'] as int?,
      title: map['title'] as String?,
      gearId: map['gear_id'] as int?,
      startedAt: DateTime.fromMillisecondsSinceEpoch((map['started_at'] as int?) ?? 0),
      endedAt: DateTime.fromMillisecondsSinceEpoch((map['ended_at'] as int?) ?? 0),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0,
      movingTimeMs: (map['moving_time_ms'] as int?) ?? 0,
      elapsedTimeMs: (map['elapsed_time_ms'] as int?) ?? 0,
      avgSpeedMps: (map['avg_speed_mps'] as num?)?.toDouble() ?? 0,
      maxSpeedMps: (map['max_speed_mps'] as num?)?.toDouble() ?? 0,
      elevationGainMeters: (map['elevation_gain_meters'] as num?)?.toDouble() ?? 0,
      note: map['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int?) ?? 0),
    );
  }

  /// Converts the activity into a database row.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'title': title,
        'gear_id': gearId,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt.millisecondsSinceEpoch,
        'distance_meters': distanceMeters,
        'moving_time_ms': movingTimeMs,
        'elapsed_time_ms': elapsedTimeMs,
        'avg_speed_mps': avgSpeedMps,
        'max_speed_mps': maxSpeedMps,
        'elevation_gain_meters': elevationGainMeters,
        'note': note,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  /// Returns a copy with the given fields replaced.
  Activity copyWith({
    int? id,
    String? title,
    int? gearId,
    DateTime? startedAt,
    DateTime? endedAt,
    double? distanceMeters,
    int? movingTimeMs,
    int? elapsedTimeMs,
    double? avgSpeedMps,
    double? maxSpeedMps,
    double? elevationGainMps,
    double? elevationGainMeters,
    String? note,
    DateTime? createdAt,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      gearId: gearId ?? this.gearId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      movingTimeMs: movingTimeMs ?? this.movingTimeMs,
      elapsedTimeMs: elapsedTimeMs ?? this.elapsedTimeMs,
      avgSpeedMps: avgSpeedMps ?? this.avgSpeedMps,
      maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
      elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Default title used when the user does not name the activity.
  String get displayTitle => title?.trim().isNotEmpty == true ? title!.trim() : 'Activity';
}
