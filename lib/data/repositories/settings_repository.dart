import 'package:sqflite/sqflite.dart';

import '../../core/db/app_database.dart';

/// Tiny key/value store for user preferences.
///
/// Keeping the preferences in the same local database avoids pulling in an
/// extra storage plugin and keeps the "everything stays on the device"
/// promise trivially auditable.
class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;

  /// Reads a raw setting value.
  Future<String?> read(String key) async {
    final rows = await _database.db.query(
      'settings',
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Writes a raw setting value.
  Future<void> write(String key, String value) async {
    await _database.db.insert(
      'settings',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Reads all settings as a map.
  Future<Map<String, String>> readAll() async {
    final rows = await _database.db.query('settings');
    return <String, String>{
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }
}
