import '../../core/db/app_database.dart';
import '../models/gear.dart';

/// Data access for the user's equipment (bicycles, shoes).
class GearRepository {
  GearRepository(this._database);

  final AppDatabase _database;

  /// Returns all gear ordered by name.
  Future<List<Gear>> listGear() async {
    final rows = await _database.db.query('gears', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Gear.fromMap).toList(growable: false);
  }

  /// Returns a single gear or `null` when it does not exist.
  Future<Gear?> findById(int id) async {
    final rows = await _database.db.query(
      'gears',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Gear.fromMap(rows.first);
  }

  /// Returns the gear flagged as default, or `null` when none is flagged.
  Future<Gear?> defaultGear() async {
    final rows = await _database.db.query(
      'gears',
      where: 'is_default = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Gear.fromMap(rows.first);
  }

  /// Inserts a gear and returns its identifier.
  Future<int> insertGear(Gear gear) async {
    final id = await _database.db.insert('gears', gear.toMap());
    if (gear.isDefault) {
      await clearOtherDefaults(id);
    }
    return id;
  }

  /// Updates an existing gear.
  Future<void> updateGear(Gear gear) async {
    await _database.db.update(
      'gears',
      gear.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[gear.id],
    );
    if (gear.isDefault && gear.id != null) {
      await clearOtherDefaults(gear.id!);
    }
  }

  /// Deletes a gear.
  Future<void> deleteGear(int id) async {
    await _database.db.delete('gears', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  /// Marks [id] as the only default gear.
  Future<void> setDefaultGear(int id) async {
    await _database.db.update(
      'gears',
      <String, Object?>{'is_default': 0},
    );
    await _database.db.update(
      'gears',
      <String, Object?>{'is_default': 1},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Adds [distanceMeters] to the accumulated distance of a gear.
  Future<void> addDistance(int id, double distanceMeters) async {
    await _database.db.rawUpdate(
      'UPDATE gears SET total_distance_meters = total_distance_meters + ?, '
      'updated_at = ? WHERE id = ?',
      <Object?>[distanceMeters, DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  /// Subtracts [distanceMeters] from the accumulated distance of a gear.
  ///
  /// Used when an activity is deleted. The total is clamped at zero so a
  /// floating point residue can never make the mileage negative.
  Future<void> subtractDistance(int id, double distanceMeters) async {
    await _database.db.rawUpdate(
      'UPDATE gears SET total_distance_meters = '
      'MAX(0, total_distance_meters - ?), updated_at = ? WHERE id = ?',
      <Object?>[distanceMeters, DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  /// Resets the accumulated distance of a gear.
  Future<void> resetDistance(int id) async {
    await _database.db.update(
      'gears',
      <String, Object?>{
        'total_distance_meters': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Makes sure only one gear is flagged as the default.
  Future<void> clearOtherDefaults(int keepId) async {
    await _database.db.update(
      'gears',
      <String, Object?>{'is_default': 0},
      where: 'id != ?',
      whereArgs: <Object?>[keepId],
    );
  }
}
