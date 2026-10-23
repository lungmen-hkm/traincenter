import 'package:sqflite/sqflite.dart';

import '../../core/db/app_database.dart';
import '../models/activity.dart';
import '../models/track_point.dart';

/// Data access for recorded activities and their GPS tracks.
///
/// Every method is local-only; the repository never talks to a network.
class ActivityRepository {
  ActivityRepository(this._database);

  final AppDatabase _database;

  /// Returns all activities, newest first.
  Future<List<Activity>> listActivities({int? gearId}) async {
    final rows = await _database.db.query(
      'activities',
      where: gearId == null ? null : 'gear_id = ?',
      whereArgs: gearId == null ? null : <Object?>[gearId],
      orderBy: 'started_at DESC',
    );
    return rows.map(Activity.fromMap).toList(growable: false);
  }

  /// Returns a single activity or `null` when it does not exist.
  Future<Activity?> findById(int id) async {
    final rows = await _database.db.query(
      'activities',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Activity.fromMap(rows.first);
  }

  /// Returns the GPS track of an activity ordered by sequence number.
  Future<List<TrackPoint>> trackPoints(int activityId) async {
    final rows = await _database.db.query(
      'track_points',
      where: 'activity_id = ?',
      whereArgs: <Object?>[activityId],
      orderBy: 'seq ASC',
    );
    return rows.map(TrackPoint.fromMap).toList(growable: false);
  }

  /// Inserts an activity together with its GPS track in a single transaction.
  ///
  /// Returns the identifier of the newly created activity.
  Future<int> insertActivity(Activity activity, List<TrackPoint> points) async {
    return _database.db.transaction<int>((txn) async {
      final activityId = await txn.insert('activities', activity.toMap());
      final batch = txn.batch();
      for (final point in points) {
        batch.insert('track_points', point.copyWith(activityId: activityId).toMap());
      }
      await batch.commit(noResult: true);
      return activityId;
    });
  }

  /// Updates an existing activity.
  Future<void> updateActivity(Activity activity) async {
    await _database.db.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[activity.id],
    );
  }

  /// Deletes an activity. The GPS track is removed by the `ON DELETE CASCADE`
  /// foreign key.
  Future<void> deleteActivity(int id) async {
    await _database.db.delete(
      'activities',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Returns the total distance of all recorded activities.
  Future<double> totalDistanceMeters() async {
    final result = await _database.db.rawQuery(
      'SELECT COALESCE(SUM(distance_meters), 0) AS total FROM activities',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// Returns the total moving time of all recorded activities in milliseconds.
  Future<int> totalMovingTimeMs() async {
    final result = await _database.db.rawQuery(
      'SELECT COALESCE(SUM(moving_time_ms), 0) AS total FROM activities',
    );
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Returns the total elevation gain of all recorded activities in metres.
  Future<double> totalElevationGainMeters() async {
    final result = await _database.db.rawQuery(
      'SELECT COALESCE(SUM(elevation_gain_meters), 0) AS total FROM activities',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  /// Convenience helper that runs [action] inside a transaction.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      _database.db.transaction<T>(action);
}
