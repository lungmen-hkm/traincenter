/// A user defined stretch of road / trail used for local segment
/// comparisons.
///
/// Segments are entirely local: they are defined from a previously recorded
/// route and never leave the device.
class Segment {
  /// Database identifier. `null` for segments that have not been persisted.
  final int? id;

  /// User supplied name, e.g. "Col de la Croix".
  final String name;

  /// Activity the segment was created from.
  final int? activityId;

  /// Latitude of the segment start point.
  final double startLatitude;

  /// Longitude of the segment start point.
  final double startLongitude;

  /// Altitude (metres) of the segment start point, when available.
  final double? startAltitude;

  /// Latitude of the segment end point.
  final double endLatitude;

  /// Longitude of the segment end point.
  final double endLongitude;

  /// Altitude (metres) of the segment end point, when available.
  final double? endAltitude;

  /// Length of the segment (metres).
  final double distanceMeters;

  /// Row creation timestamp.
  final DateTime createdAt;

  const Segment({
    this.id,
    required this.name,
    this.activityId,
    required this.startLatitude,
    required this.startLongitude,
    this.startAltitude,
    required this.endLatitude,
    required this.endLongitude,
    this.endAltitude,
    required this.distanceMeters,
    required this.createdAt,
  });

  /// Builds a segment from a database row.
  factory Segment.fromMap(Map<String, Object?> map) {
    return Segment(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? 'Segment',
      activityId: map['activity_id'] as int?,
      startLatitude: (map['start_lat'] as num?)?.toDouble() ?? 0,
      startLongitude: (map['start_lng'] as num?)?.toDouble() ?? 0,
      startAltitude: (map['start_altitude'] as num?)?.toDouble(),
      endLatitude: (map['end_lat'] as num?)?.toDouble() ?? 0,
      endLongitude: (map['end_lng'] as num?)?.toDouble() ?? 0,
      endAltitude: (map['end_altitude'] as num?)?.toDouble(),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch((map['created_at'] as int?) ?? 0),
    );
  }

  /// Converts the segment into a database row.
  Map<String, Object?> toMap() => <String, Object?>{
        if (id != null) 'id': id,
        'name': name,
        'activity_id': activityId,
        'start_lat': startLatitude,
        'start_lng': startLongitude,
        'start_altitude': startAltitude,
        'end_lat': endLatitude,
        'end_lng': endLongitude,
        'end_altitude': endAltitude,
        'distance_meters': distanceMeters,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  /// Returns a copy with the given fields replaced.
  Segment copyWith({
    int? id,
    String? name,
    int? activityId,
    double? startLatitude,
    double? startLongitude,
    double? startAltitude,
    double? endLatitude,
    double? endLongitude,
    double? endAltitude,
    double? distanceMeters,
    DateTime? createdAt,
  }) {
    return Segment(
      id: id ?? this.id,
      name: name ?? this.name,
      activityId: activityId ?? this.activityId,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      startAltitude: startAltitude ?? this.startAltitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      endAltitude: endAltitude ?? this.endAltitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
