import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single, on-device SQLite database used by TrainCenter.
///
/// TrainCenter is *offline first*: this database is the only source of truth.
/// There is no API client, no sync engine and no remote cache anywhere in the
/// application.
class AppDatabase {
  /// Creates the database handle.
  AppDatabase({String fileName = 'traincenter.db'}) : _fileName = fileName;

  /// Name of the SQLite file inside the platform databases directory.
  final String _fileName;

  Database? _database;

  /// The opened database instance.
  ///
  /// Throws a [StateError] when [open] has not been awaited yet.
  Database get db {
    final database = _database;
    if (database == null) {
      throw StateError('AppDatabase.open() must be awaited before use.');
    }
    return database;
  }

  /// Whether the database has been opened.
  bool get isOpen => _database != null;

  /// Opens (and creates if needed) the local database.
  Future<Database> open() async {
    if (_database != null) return _database!;

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _fileName);

    _database = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        // Enforce relational integrity so deleting an activity also removes
        // its GPS track and segment efforts.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        for (final statement in createStatements) {
          await db.execute(statement);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Future migrations are appended here. The app has never shipped, so
        // there is no legacy schema to migrate from yet.
      },
    );

    return _database!;
  }

  /// Closes the database. Mostly useful for tests.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Removes every row of every table. Used by the "erase all data" action
  /// in the settings screen.
  Future<void> wipe() async {
    final batch = db.batch();
    for (final table in deletableTables) {
      batch.delete(table);
    }
    await batch.commit(noResult: true);
  }

  /// Current schema version.
  static const int schemaVersion = 1;

  /// Tables that are cleared by [wipe], ordered so that foreign keys are
  /// satisfied.
  static const List<String> deletableTables = <String>[
    'segment_efforts',
    'segments',
    'track_points',
    'activities',
    'gears',
    'settings',
  ];

  /// `CREATE TABLE` statements executed when the database is created.
  static const List<String> createStatements = <String>[
    '''
    CREATE TABLE gears (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      brand TEXT,
      model TEXT,
      type TEXT NOT NULL,
      total_distance_meters REAL NOT NULL DEFAULT 0,
      is_default INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE activities (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      gear_id INTEGER,
      started_at INTEGER NOT NULL,
      ended_at INTEGER NOT NULL,
      distance_meters REAL NOT NULL,
      moving_time_ms INTEGER NOT NULL,
      elapsed_time_ms INTEGER NOT NULL,
      avg_speed_mps REAL NOT NULL,
      max_speed_mps REAL NOT NULL,
      elevation_gain_meters REAL NOT NULL,
      note TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (gear_id) REFERENCES gears (id) ON DELETE SET NULL
    )
    ''',
    '''
    CREATE TABLE track_points (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      activity_id INTEGER NOT NULL,
      seq INTEGER NOT NULL,
      lat REAL NOT NULL,
      lng REAL NOT NULL,
      altitude REAL,
      speed REAL,
      accuracy REAL,
      timestamp INTEGER NOT NULL,
      FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE segments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      activity_id INTEGER,
      start_lat REAL NOT NULL,
      start_lng REAL NOT NULL,
      start_altitude REAL,
      end_lat REAL NOT NULL,
      end_lng REAL NOT NULL,
      end_altitude REAL,
      distance_meters REAL NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE SET NULL
    )
    ''',
    '''
    CREATE TABLE segment_efforts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      segment_id INTEGER NOT NULL,
      activity_id INTEGER NOT NULL,
      time_ms INTEGER NOT NULL,
      avg_speed_mps REAL NOT NULL,
      is_pr INTEGER NOT NULL DEFAULT 0,
      achieved_at INTEGER NOT NULL,
      FOREIGN KEY (segment_id) REFERENCES segments (id) ON DELETE CASCADE,
      FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
    ''',
    '''
    CREATE INDEX idx_track_points_activity ON track_points (activity_id, seq)
    ''',
    '''
    CREATE INDEX idx_activities_started ON activities (started_at DESC)
    ''',
    '''
    CREATE INDEX idx_segment_efforts_segment ON segment_efforts (segment_id)
    ''',
  ];
}
