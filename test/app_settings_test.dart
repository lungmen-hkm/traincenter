import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:traincenter/core/db/app_database.dart';
import 'package:traincenter/data/repositories/settings_repository.dart';
import 'package:traincenter/features/settings/app_settings.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  test('the selected theme survives a reload', () async {
    final database = AppDatabase(
      fileName: 'settings_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await database.open();
    addTearDown(database.close);

    final repository = SettingsRepository(database);

    final settings = AppSettings(repository);
    await settings.load();
    expect(settings.themeMode, AppThemeMode.system);

    await settings.setThemeMode(AppThemeMode.dark);

    // Simulate the next app start: a fresh controller reads the same database.
    final reloaded = AppSettings(repository);
    await reloaded.load();
    expect(reloaded.themeMode, AppThemeMode.dark);
  });
}
