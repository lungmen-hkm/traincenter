import '../../core/db/app_database.dart';
import '../models/segment.dart';
import '../models/segment_effort.dart';

/// Data access for locally defined segments and the efforts recorded on them.
class SegmentRepository {
  SegmentRepository(this._database);

  final AppDatabase _database;

  /// Returns all segments, newest first.
  Future<List<Segment>> listSegments() async {
    final rows = await _database.db.query('segments', orderBy: 'created_at DESC');
    return rows.map(Segment.fromMap).toList(growable: false);
  }

  /// Returns a single segment or `null` when it does not exist.
  Future<Segment?> findById(int id) async {
    final rows = await _database.db.query(
      'segments',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Segment.fromMap(rows.first);
  }

  /// Inserts a segment and returns its identifier.
  Future<int> insertSegment(Segment segment) async {
    return _database.db.insert('segments', segment.toMap());
  }

  /// Updates an existing segment.
  Future<void> updateSegment(Segment segment) async {
    await _database.db.update(
      'segments',
      segment.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[segment.id],
    );
  }

  /// Deletes a segment together with all of its efforts.
  Future<void> deleteSegment(int id) async {
    await _database.db.delete('segments', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Returns every effort recorded on a segment, fastest first.
  Future<List<SegmentEffort>> effortsFor(int segmentId) async {
    final rows = await _database.db.query(
      'segment_efforts',
      where: 'segment_id = ?',
      whereArgs: <Object?>[segmentId],
      orderBy: 'time_ms ASC',
    );
    return rows.map(SegmentEffort.fromMap).toList(growable: false);
  }

  /// Returns the fastest effort ever recorded on a segment.
  Future<SegmentEffort?> bestEffort(int segmentId) async {
    final rows = await _database.db.query(
      'segment_efforts',
      where: 'segment_id = ?',
      whereArgs: <Object?>[segmentId],
      orderBy: 'time_ms ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SegmentEffort.fromMap(rows.first);
  }

  /// Inserts an effort.
  Future<int> insertEffort(SegmentEffort effort) async {
    return _database.db.insert('segment_efforts', effort.toMap());
  }

  /// Updates an existing effort.
  Future<void> updateEffort(SegmentEffort effort) async {
    await _database.db.update(
      'segment_efforts',
      effort.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[effort.id],
    );
  }

  /// Deletes all efforts recorded on a segment.
  Future<void> deleteEfforts(int segmentId) async {
    await _database.db.delete(
      'segment_efforts',
      where: 'segment_id = ?',
      whereArgs: <Object?>[segmentId],
    );
  }

  /// Recomputes the `is_pr` flag of every stored effort.
  ///
  /// Deleting an activity cascades to its efforts. If that activity held the
  /// personal best, the next-fastest effort has to be promoted; otherwise the
  /// activity detail would still label it as an ordinary effort. Ties are
  /// broken by id so exactly one effort per segment is flagged.
  Future<void> recalculatePersonalBests() async {
    await _database.db.rawUpdate(
      'UPDATE segment_efforts SET is_pr = CASE WHEN id = ('
      '  SELECT e2.id FROM segment_efforts e2 '
      '  WHERE e2.segment_id = segment_efforts.segment_id '
      '  ORDER BY e2.time_ms ASC, e2.id ASC LIMIT 1'
      ') THEN 1 ELSE 0 END',
    );
  }
}
