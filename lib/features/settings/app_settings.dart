import 'package:flutter/foundation.dart';

import '../../core/utils/formatters.dart';
import '../../data/repositories/settings_repository.dart';

/// Where the map tiles come from.
enum MapTileSource {
  /// Tiles are downloaded from the public OpenStreetMap servers.
  ///
  /// Only the tile coordinates are sent; no activity data ever leaves the
  /// device. Users who want a completely silent build can pick
  /// [MapTileSource.none] or [MapTileSource.offline].
  openStreetMap,

  /// Tiles are read from the bundled `assets/maptiles` folder, which makes
  /// the map work completely offline.
  offline,

  /// No tiles at all. The map renders the recorded route as pure vector
  /// geometry on a neutral canvas.
  none;

  /// Human readable label.
  String get label => switch (this) {
        MapTileSource.openStreetMap => 'OpenStreetMap (online)',
        MapTileSource.offline => 'Offline tiles (bundled)',
        MapTileSource.none => 'No tiles (vector only)',
      };
}

/// Brightness used when rendering the shareable PNG card.
enum ExportBrightness {
  /// Follow the app theme.
  system,

  /// Always render the card for a light background.
  light,

  /// Always render the card for a dark background.
  dark;

  /// Human readable label.
  String get label => switch (this) {
        ExportBrightness.system => 'Follow app theme',
        ExportBrightness.light => 'Light',
        ExportBrightness.dark => 'Dark',
      };
}

/// User preferences of the application.
///
/// Everything is persisted in the local SQLite database, there is no remote
/// configuration and no account.
class AppSettings extends ChangeNotifier {
  /// Creates the settings controller and loads the persisted values.
  AppSettings(this._repository);

  final SettingsRepository _repository;

  static const String _keyUnits = 'units';
  static const String _keyMapTiles = 'map_tile_source';
  static const String _keyBackgroundTracking = 'background_tracking';
  static const String _keyAutoPause = 'auto_pause';
  static const String _keyExportBrightness = 'export_brightness';
  static const String _keyKeepScreenOn = 'keep_screen_on';

  UnitSystem _units = UnitSystem.metric;
  MapTileSource _mapTileSource = MapTileSource.openStreetMap;
  bool _backgroundTracking = true;
  bool _autoPause = false;
  bool _keepScreenOn = true;
  ExportBrightness _exportBrightness = ExportBrightness.system;

  /// Unit system used for all distance / speed / elevation values.
  UnitSystem get units => _units;

  /// Source of the map tiles.
  MapTileSource get mapTileSource => _mapTileSource;

  /// Whether the recording keeps running in the background.
  bool get backgroundTracking => _backgroundTracking;

  /// Whether the recording auto-pauses when the athlete stops moving.
  bool get autoPause => _autoPause;

  /// Whether the screen stays awake while recording.
  bool get keepScreenOn => _keepScreenOn;

  /// Brightness used for the exported PNG card.
  ExportBrightness get exportBrightness => _exportBrightness;

  /// Loads the persisted settings.
  Future<void> load() async {
    final values = await _repository.readAll();

    _units = UnitSystem.values.firstWhere(
      (value) => value.name == values[_keyUnits],
      orElse: () => UnitSystem.metric,
    );
    _mapTileSource = MapTileSource.values.firstWhere(
      (value) => value.name == values[_keyMapTiles],
      orElse: () => MapTileSource.openStreetMap,
    );
    _backgroundTracking = values[_keyBackgroundTracking] != 'false';
    _autoPause = values[_keyAutoPause] == 'true';
    _keepScreenOn = values[_keyKeepScreenOn] != 'false';
    _exportBrightness = ExportBrightness.values.firstWhere(
      (value) => value.name == values[_keyExportBrightness],
      orElse: () => ExportBrightness.system,
    );

    notifyListeners();
  }

  /// Sets the unit system.
  Future<void> setUnits(UnitSystem value) async {
    if (_units == value) return;
    _units = value;
    notifyListeners();
    await _repository.write(_keyUnits, value.name);
  }

  /// Sets the map tile source.
  Future<void> setMapTileSource(MapTileSource value) async {
    if (_mapTileSource == value) return;
    _mapTileSource = value;
    notifyListeners();
    await _repository.write(_keyMapTiles, value.name);
  }

  /// Enables or disables background tracking.
  Future<void> setBackgroundTracking(bool value) async {
    if (_backgroundTracking == value) return;
    _backgroundTracking = value;
    notifyListeners();
    await _repository.write(_keyBackgroundTracking, '$value');
  }

  /// Enables or disables auto pause.
  Future<void> setAutoPause(bool value) async {
    if (_autoPause == value) return;
    _autoPause = value;
    notifyListeners();
    await _repository.write(_keyAutoPause, '$value');
  }

  /// Enables or disables keeping the screen awake.
  Future<void> setKeepScreenOn(bool value) async {
    if (_keepScreenOn == value) return;
    _keepScreenOn = value;
    notifyListeners();
    await _repository.write(_keyKeepScreenOn, '$value');
  }

  /// Sets the brightness of the exported PNG card.
  Future<void> setExportBrightness(ExportBrightness value) async {
    if (_exportBrightness == value) return;
    _exportBrightness = value;
    notifyListeners();
    await _repository.write(_keyExportBrightness, value.name);
  }
}
