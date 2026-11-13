import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/services/offline_map_downloader.dart';
import '../../core/services/offline_map_store.dart';

/// Owns the offline map download state and exposes it to the settings UI.
class OfflineMapController extends ChangeNotifier {
  /// Creates a controller for [store].
  ///
  /// [downloader] is injectable for tests.
  OfflineMapController(this._store, {OfflineMapDownloader? downloader})
    : _downloader = downloader ?? OfflineMapDownloader(store: _store);

  final OfflineMapStore _store;
  final OfflineMapDownloader _downloader;

  OfflineTileSummary _summary = OfflineTileSummary.empty;
  bool _loading = true;
  bool _downloading = false;
  bool _disposed = false;
  OfflineMapDownloadProgress? _progress;
  OfflineMapDownloadResult? _lastResult;
  String? _errorMessage;
  OfflineMapDownloadToken? _token;

  /// Tiles currently stored on the device.
  OfflineTileSummary get summary => _summary;

  /// Whether the initial storage scan is still running.
  bool get isLoading => _loading;

  /// Whether a download is in progress.
  bool get isDownloading => _downloading;

  /// Current download progress, if any.
  OfflineMapDownloadProgress? get progress => _progress;

  /// Result of the most recent download, if any.
  OfflineMapDownloadResult? get lastResult => _lastResult;

  /// Human readable error from the most recent download.
  String? get errorMessage => _errorMessage;

  /// Whether at least one offline tile is available.
  bool get hasTiles => _summary.hasTiles;

  /// Absolute directory of the downloaded tiles.
  String? get directoryPath => _store.directoryPath;

  /// Reloads the storage summary.
  Future<void> load() async {
    _loading = true;
    _notify();
    final summary = await _store.summary();
    if (_disposed) return;
    _summary = summary;
    _loading = false;
    _notify();
  }

  /// Downloads the visible [bounds] for the requested zoom range.
  Future<void> downloadArea({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
  }) async {
    if (_downloading) return;

    _downloading = true;
    _errorMessage = null;
    _lastResult = null;
    _progress = OfflineMapDownloadProgress.zero(0);
    final token = OfflineMapDownloadToken();
    _token = token;
    _notify();

    try {
      final result = await _downloader.downloadArea(
        bounds: bounds,
        minZoom: minZoom,
        maxZoom: maxZoom,
        token: token,
        onProgress: (progress) {
          if (_disposed) return;
          _progress = progress;
          _notify();
        },
      );
      if (_disposed) return;
      _lastResult = result;
      _summary = await _store.summary();
    } on Object catch (error) {
      if (_disposed) return;
      _errorMessage = error is OfflineMapDownloadException
          ? error.message
          : 'Download failed: $error';
      _summary = await _store.summary();
    } finally {
      if (!_disposed) {
        _downloading = false;
        _token = null;
        _notify();
      }
    }
  }

  /// Requests cancellation of the running download.
  void cancelDownload() => _token?.cancel();

  /// Deletes every downloaded tile.
  Future<void> clear() async {
    if (_downloading) return;
    await _store.clear();
    if (_disposed) return;
    _summary = await _store.summary();
    _lastResult = null;
    _errorMessage = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel();
    super.dispose();
  }
}
