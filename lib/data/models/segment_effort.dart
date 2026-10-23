/// A single pass over a [Segment] performed during a recorded activity.
class SegmentEffort {
  /// Database identifier. `null` for efforts that have not been persisted.
  final int? id;

  /// Segment this effort belongs to.
  final int segmentId;

  /// Activity the effort was recorded in.
  final int activityId;

  /// Time taken to complete the segment (milliseconds).
  final int timeMs;

  /// Average speed across the segment (metres per second).
  final double avgSpeedMps;

  /// Whether this effort is the fastest recorded time for the segment.
  final bool isPersonalBest;

  /// Timestamp the effort was achieved.
  final DateTime achievedAt;

  const SegmentEffort({
    this.id,
    required this.segmentId,
    required this.activityId,
    required this.timeMs,
    required this.avgSpeedMps,
    this.isPersonalBest = false,
    required this.achievedAt,
  });

  /// Builds an effort from a database row.
  factory SegmentEffort.fromMap(Map<String, Object?> map) {
    return SegmentEffort(
      id: map['id'] as int?,
      segmentId: (map['segment_id'] as int?) ?? 0,
      activityId: (map['activity_id'] as int?) ?? 0,
      timeMs: (map['time_ms'] as int?) ?? 0,
      avgSpeedMps: (map['avg_speed_mps'] as num?)?.toDouble() ?? 0,
      isPersonalBest: ((map['is_pr'] as int?) ?? 0) == 1,
      achievedAt: DateTime.fromMillisecondsSinceEpoch((map['achieved_at'] as int?) ?? 0),
    );
  }

  /// Converts the effort into a database row.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'segment_id': segmentId,
        'activity_id': activityId,
        'time_ms': timeMs,
        'avg_speed_mps': avgSpeedMps,
        'is_pr': isPersonalBest ? 1 : 0,
        'achieved_at': achievedAt.millisecondsSinceEpoch,
      };

  /// Returns a copy with the given fields replaced.
  SegmentEffort copyWith({
    int? id,
    int? segmentId,
    int? activityId,
    int? timeMs,
    double? avgSpeedMps,
    bool? isPersonalBest,
    DateTime? achievedAt,
  }) {
    return SegmentEffort(
      id: id ?? this.id,
      segmentId: segmentId ?? this.segmentId,
      activityId: activityId ?? this.activityId,
      timeMs: timeMs ?? this.timeMs,
      avgSpeedMps: avgSpeedMps ?? this.avgSpeedMps,
      isPersonalBest: isPersonalBest ?? this.isPersonalBest,
      achievedAt: achievedAt ?? this.achievedAt,
    );
  }
}
