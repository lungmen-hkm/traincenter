/// Application-wide constants for TrainCenter.
///
/// Keeping magic numbers in one place makes the behaviour of the recording
/// pipeline explicit and easy to tune.
abstract final class AppConstants {
  /// Application / package identifier, also used as the tile server
  /// `User-Agent` so open tile servers can identify the client.
  static const String packageName = 'com.previx.traincenter';

  /// Human readable application name.
  static const String appName = 'TrainCenter';

  /// Maximum accepted horizontal GPS accuracy (metres) for a fix to be
  /// recorded. Anything worse is treated as noise and dropped.
  static const double maxAcceptedAccuracyMeters = 30.0;

  /// Minimum distance (metres) between two recorded points. Filters out GPS
  /// jitter when standing still.
  static const double minPointDistanceMeters = 2.0;

  /// Maximum plausible speed (m/s ≈ 400 km/h) used to reject teleporting
  /// fixes caused by a GPS re-acquisition.
  static const double maxPlausibleSpeedMps = 110.0;

  /// Maximum age of the first accepted fix. A cached location from before the
  /// recording was started must not become the first track point: it would
  /// connect the old position to the new one with a phantom straight line.
  static const Duration maxInitialFixAge = Duration(seconds: 10);

  /// Speed (m/s) above which the athlete is considered "moving".
  static const double movingSpeedThresholdMps = 0.5;

  /// Continuous standstill after which the recording is auto-paused.
  static const Duration autoPauseDelay = Duration(seconds: 20);

  /// Minimum altitude difference (metres) between two samples before it is
  /// counted towards the elevation gain.
  static const double minElevationDeltaMeters = 0.5;

  /// Radius (metres) around a segment start/end point that still counts as a
  /// match when computing segment efforts.
  static const double segmentEndpointRadiusMeters = 60.0;

  /// Half-width (metres) of the corridor around a segment line that is
  /// considered "on" the segment.
  static const double segmentCorridorRadiusMeters = 35.0;

  /// Shortest segment length (metres) that can be created.
  static const double minSegmentLengthMeters = 100.0;

  /// Interval at which the recording screen refreshes its elapsed timer.
  static const Duration tickerInterval = Duration(seconds: 1);

  /// Interval used for the high accuracy GPS stream.
  static const Duration gpsInterval = Duration(seconds: 2);

  /// Distance filter (metres) used for the high accuracy GPS stream.
  static const int gpsDistanceFilterMeters = 1;

  /// Hard cap for a single offline map download.
  ///
  /// The public OpenStreetMap tile servers are run by volunteers. Keeping a
  /// download to a small, deliberately selected area is both friendlier to
  /// them and keeps the app's storage footprint predictable.
  static const int offlineMapMaxTiles = 1500;

  /// Lowest zoom level that can be selected for an offline download.
  static const int offlineMapMinZoom = 10;

  /// Highest zoom level that can be selected for an offline download.
  static const int offlineMapMaxZoom = 17;

  /// Default zoom range used by the offline map downloader.
  static const int offlineMapDefaultMinZoom = 12;
  static const int offlineMapDefaultMaxZoom = 16;

  /// Zoom used when the download screen centres on the last known position.
  ///
  /// This is deliberately one level wider than the record screen's default
  /// zoom so the downloaded area also covers the taller full-screen map.
  static const int offlineMapPreviewZoom = 13;

  /// Extra margin around the preview bounds, as a fraction of each span.
  ///
  /// The preview map is much shorter than the full-screen record map. Padding
  /// the download area keeps the offline map covered when the user switches
  /// back to the record screen.
  static const double offlineMapDownloadMargin = 0.25;

  /// Rough average size of one OSM raster tile, used for the size estimate.
  ///
  /// The real size varies with the amount of detail on the tile; this value
  /// only exists to give the user an order of magnitude before downloading.
  static const int offlineMapEstimatedTileBytes = 20 * 1024;
}
