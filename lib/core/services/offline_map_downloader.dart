import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';

import '../constants/app_constants.dart';
import 'offline_map_store.dart';
import 'offline_map_tiles.dart';

/// Fetches a single tile from a URL.
typedef OfflineMapTileFetcher = Future<Uint8List> Function(Uri uri);

/// Progress of a running offline map download.
class OfflineMapDownloadProgress {
  /// Creates a progress snapshot.
  const OfflineMapDownloadProgress({
    required this.total,
    required this.completed,
    required this.downloaded,
    required this.skipped,
    required this.bytes,
  });

  /// Initial progress for a download of [total] tiles.
  factory OfflineMapDownloadProgress.zero(int total) {
    return OfflineMapDownloadProgress(
      total: total,
      completed: 0,
      downloaded: 0,
      skipped: 0,
      bytes: 0,
    );
  }

  /// Number of tiles in the plan.
  final int total;

  /// Tiles already processed (downloaded or skipped).
  final int completed;

  /// Tiles newly downloaded in this run.
  final int downloaded;

  /// Tiles that already existed and were skipped.
  final int skipped;

  /// Bytes downloaded in this run.
  final int bytes;

  /// Value between 0 and 1 for progress indicators.
  double get fraction => total == 0 ? 0 : completed / total;
}

/// Result of a finished download.
class OfflineMapDownloadResult {
  /// Creates a download result.
  const OfflineMapDownloadResult({
    required this.total,
    required this.downloaded,
    required this.skipped,
    required this.bytes,
    required this.cancelled,
  });

  /// Number of tiles in the plan.
  final int total;

  /// Tiles newly downloaded.
  final int downloaded;

  /// Tiles that were already stored.
  final int skipped;

  /// Bytes downloaded in this run.
  final int bytes;

  /// Whether the user cancelled the download.
  final bool cancelled;
}

/// Error raised when a download cannot be completed.
class OfflineMapDownloadException implements Exception {
  /// Creates an exception with a human readable [message].
  const OfflineMapDownloadException(this.message);

  /// Description shown in the UI.
  final String message;

  @override
  String toString() => message;
}

/// Cancellation token shared with the download screen.
class OfflineMapDownloadToken {
  bool _cancelled = false;

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled;

  /// Requests cancellation.
  void cancel() => _cancelled = true;
}

/// Downloads OpenStreetMap raster tiles into [OfflineMapStore].
class OfflineMapDownloader {
  /// Creates a downloader.
  ///
  /// [fetchTile] is injectable so the download logic can be tested without
  /// touching the network.
  OfflineMapDownloader({
    OfflineMapStore? store,
    OfflineMapTileFetcher? fetchTile,
  }) : _store = store ?? OfflineMapStore.instance,
       _fetchTile = fetchTile;

  final OfflineMapStore _store;
  final OfflineMapTileFetcher? _fetchTile;

  static const int _parallelDownloads = 3;

  /// Builds the public OSM tile URL for a coordinate.
  static Uri tileUri(int z, int x, int y) {
    return Uri.https('tile.openstreetmap.org', '/$z/$x/$y.png');
  }

  /// Downloads every tile needed to cover [bounds].
  ///
  /// Existing tiles are skipped, so a cancelled or failed download can be
  /// resumed by running the same area again.
  Future<OfflineMapDownloadResult> downloadArea({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    required OfflineMapDownloadToken token,
    void Function(OfflineMapDownloadProgress progress)? onProgress,
  }) async {
    await _store.initialize();
    if (!_store.isAvailable) {
      throw const OfflineMapDownloadException(
        'Offline map storage is unavailable on this device.',
      );
    }

    // Count first: materialising the tile list for a zoomed-out world view
    // would allocate millions of objects before the limit check runs.
    final tileCount = SlippyMapTiles.tileCount(bounds, minZoom, maxZoom);
    if (tileCount > AppConstants.offlineMapMaxTiles) {
      throw OfflineMapDownloadException(
        'This area needs $tileCount tiles, which is more than the '
        '${AppConstants.offlineMapMaxTiles}-tile limit. Zoom in or lower the '
        'maximum zoom level.',
      );
    }

    final tiles = SlippyMapTiles.tiles(
      bounds,
      minZoom,
      maxZoom,
    ).toList(growable: false);
    final total = tiles.length;
    var completed = 0;
    var downloaded = 0;
    var skipped = 0;
    var bytes = 0;
    Object? failure;

    void report() {
      onProgress?.call(
        OfflineMapDownloadProgress(
          total: total,
          completed: completed,
          downloaded: downloaded,
          skipped: skipped,
          bytes: bytes,
        ),
      );
    }

    report();

    final client = _fetchTile == null ? HttpClient() : null;
    if (client != null) {
      client.connectionTimeout = const Duration(seconds: 15);
      client.idleTimeout = const Duration(seconds: 15);
    }

    try {
      var nextIndex = 0;

      Future<void> worker() async {
        while (!token.isCancelled && failure == null) {
          final index = nextIndex++;
          if (index >= tiles.length) return;

          final tile = tiles[index];
          final file = _store.fileFor(tile.z, tile.x, tile.y);

          if (file != null && await file.exists() && await file.length() > 0) {
            skipped++;
            completed++;
            report();
            continue;
          }

          try {
            final tileBytes = await _loadTile(tile, client);
            await _store.writeTile(tile.z, tile.x, tile.y, tileBytes);
            downloaded++;
            bytes += tileBytes.length;
            completed++;
            report();
          } on Object catch (error) {
            failure ??= error;
            return;
          }
        }
      }

      await Future.wait(<Future<void>>[
        for (var i = 0; i < _parallelDownloads; i++) worker(),
      ]);

      if (failure != null) throw failure!;

      return OfflineMapDownloadResult(
        total: total,
        downloaded: downloaded,
        skipped: skipped,
        bytes: bytes,
        cancelled: token.isCancelled,
      );
    } finally {
      client?.close(force: true);
    }
  }

  Future<Uint8List> _loadTile(
    OfflineTileCoordinate tile,
    HttpClient? client,
  ) async {
    final uri = tileUri(tile.z, tile.x, tile.y);
    final injectedFetcher = _fetchTile;
    if (injectedFetcher != null) return injectedFetcher(uri);

    final request = await client!.getUrl(uri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      '${AppConstants.appName}/1.0 (${AppConstants.packageName})',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'image/png,image/*;q=0.8');

    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw OfflineMapDownloadException(
        'Tile ${tile.z}/${tile.x}/${tile.y} returned HTTP '
        '${response.statusCode}.',
      );
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      throw OfflineMapDownloadException(
        'Tile ${tile.z}/${tile.x}/${tile.y} was empty.',
      );
    }
    return bytes;
  }
}
