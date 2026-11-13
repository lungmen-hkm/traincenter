import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/formatters.dart';

/// Summary of the tiles currently stored on the device.
class OfflineTileSummary {
  /// Creates a tile summary.
  const OfflineTileSummary({required this.tileCount, required this.bytes});

  /// No tiles are stored.
  static const OfflineTileSummary empty = OfflineTileSummary(
    tileCount: 0,
    bytes: 0,
  );

  /// Number of PNG tiles.
  final int tileCount;

  /// Total size of those tiles in bytes.
  final int bytes;

  /// Whether at least one tile is stored.
  bool get hasTiles => tileCount > 0;

  /// Human readable storage size.
  String get sizeLabel => Formatters.fileSize(bytes);
}

/// Stores downloaded raster tiles in the app-support directory.
///
/// Tiles use the standard slippy-map layout:
///
/// ```text
/// <support>/offline_maps/{z}/{x}/{y}.png
/// ```
///
/// The store is intentionally tiny and dependency free: downloading and
/// rendering are handled by separate classes.
class OfflineMapStore {
  /// Creates a store.
  ///
  /// [root] is primarily useful in tests; production code uses [instance].
  OfflineMapStore({Directory? root}) : _rootOverride = root;

  /// The app-wide store used by the map and the settings UI.
  static final OfflineMapStore instance = OfflineMapStore();

  /// Folder name below the platform's application-support directory.
  static const String folderName = 'offline_maps';

  final Directory? _rootOverride;
  Directory? _root;
  Future<void>? _initialization;

  /// The directory that holds the tiles, or `null` when storage is
  /// unavailable on this platform.
  Directory? get root => _root;

  /// Absolute path of the tile directory, or `null` before initialization.
  String? get directoryPath => _root?.path;

  /// Whether the store has a usable directory.
  bool get isAvailable => _root != null;

  /// Resolves and creates the tile directory.
  ///
  /// Failure is non-fatal: the app simply reports that offline maps are
  /// unavailable instead of preventing startup.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final root =
          _rootOverride ??
          Directory(
            p.join((await getApplicationSupportDirectory()).path, folderName),
          );
      await root.create(recursive: true);
      _root = root;
    } on Object {
      _root = null;
    }
  }

  /// Returns the file for a tile, or `null` when storage is unavailable.
  File? fileFor(int z, int x, int y) {
    final root = _root;
    if (root == null) return null;
    return File(p.join(root.path, '$z', '$x', '$y.png'));
  }

  /// Writes a downloaded tile atomically.
  Future<void> writeTile(int z, int x, int y, List<int> bytes) async {
    await initialize();
    final file = fileFor(z, x, y);
    if (file == null) {
      throw const FileSystemException('Offline map storage is unavailable.');
    }

    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.part');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  }

  /// Counts the stored tiles and their total size.
  Future<OfflineTileSummary> summary() async {
    await initialize();
    final root = _root;
    if (root == null || !await root.exists()) {
      return OfflineTileSummary.empty;
    }

    var tileCount = 0;
    var bytes = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.png')) continue;
      tileCount++;
      bytes += await entity.length();
    }
    return OfflineTileSummary(tileCount: tileCount, bytes: bytes);
  }

  /// Removes every downloaded tile.
  Future<void> clear() async {
    await initialize();
    final root = _root;
    if (root == null) return;

    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    await root.create(recursive: true);
  }
}
