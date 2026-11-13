import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart' as p;

/// Serves downloaded tiles from [directoryPath] and falls back to the bundled
/// `assets/maptiles` pack when a downloaded tile does not exist.
class OfflineTileProvider extends TileProvider {
  /// Creates a provider for a tile directory.
  ///
  /// [directoryPath] may be `null` when offline storage is unavailable; the
  /// provider then behaves like the standard asset tile provider.
  OfflineTileProvider({required this.directoryPath});

  /// Root folder containing `{z}/{x}/{y}.png` files.
  final String? directoryPath;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final root = directoryPath;
    if (root != null) {
      final file = File(
        p.join(
          root,
          '${coordinates.z}',
          '${coordinates.x}',
          '${coordinates.y}.png',
        ),
      );
      if (file.existsSync()) return FileImage(file);
    }

    return AssetImage(
      'assets/maptiles/${coordinates.z}/${coordinates.x}/${coordinates.y}.png',
    );
  }
}
