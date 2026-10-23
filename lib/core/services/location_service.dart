import 'package:flutter/foundation.dart';

/// A single GPS fix.
///
/// The domain layer never touches plugin specific types (`Position`,
/// `LatLng`, ...) which keeps the recording pipeline unit-testable and makes
/// it trivial to swap the underlying location provider.
@immutable
class LocationFix {
  /// Latitude in degrees (WGS84).
  final double latitude;

  /// Longitude in degrees (WGS84).
  final double longitude;

  /// Altitude in metres above the WGS84 ellipsoid, when the device provides it.
  final double? altitude;

  /// Instantaneous speed in metres per second, when the device provides it.
  final double? speedMps;

  /// Horizontal accuracy radius in metres, when the device provides it.
  final double? accuracyMeters;

  /// Time the fix was produced.
  final DateTime timestamp;

  const LocationFix({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speedMps,
    this.accuracyMeters,
    required this.timestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationFix &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.altitude == altitude &&
          other.speedMps == speedMps &&
          other.accuracyMeters == accuracyMeters &&
          other.timestamp == timestamp;

  @override
  int get hashCode =>
      Object.hash(latitude, longitude, altitude, speedMps, accuracyMeters, timestamp);
}

/// Describes whether the app is allowed to read the device location.
enum LocationPermissionState {
  /// Location access has been granted (possibly only while using the app).
  granted,

  /// The user denied the permission but can be asked again.
  denied,

  /// The user selected "don't ask again"; only the app settings can change it.
  deniedForever,

  /// The permission is granted but the device location service is switched off.
  serviceDisabled;

  /// Whether a location stream can be started.
  bool get isUsable => this == LocationPermissionState.granted;
}

/// Configuration of a GPS stream.
@immutable
class LocationTrackingOptions {
  /// Desired interval between two fixes.
  final Duration interval;

  /// Minimum distance (metres) between two reported fixes.
  final int distanceFilterMeters;

  /// Whether the stream should keep running while the app is backgrounded.
  ///
  /// On Android this is implemented through a foreground service, which is the
  /// only mechanism the platform offers for continuous GPS access.
  final bool allowBackground;

  /// Title of the foreground-service notification (Android only).
  final String notificationTitle;

  /// Body of the foreground-service notification (Android only).
  final String notificationText;

  const LocationTrackingOptions({
    this.interval = const Duration(seconds: 2),
    this.distanceFilterMeters = 1,
    this.allowBackground = false,
    this.notificationTitle = 'TrainCenter',
    this.notificationText = 'Recording your activity',
  });

  /// Returns a copy with the given fields replaced.
  LocationTrackingOptions copyWith({
    Duration? interval,
    int? distanceFilterMeters,
    bool? allowBackground,
    String? notificationTitle,
    String? notificationText,
  }) {
    return LocationTrackingOptions(
      interval: interval ?? this.interval,
      distanceFilterMeters: distanceFilterMeters ?? this.distanceFilterMeters,
      allowBackground: allowBackground ?? this.allowBackground,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationText: notificationText ?? this.notificationText,
    );
  }
}

/// Platform agnostic contract for reading the device location.
///
/// The rest of the app only ever talks to this interface, which is what makes
/// the background tracking strategy swappable.
abstract class LocationService {
  /// Whether the device location service is switched on.
  Future<bool> isServiceEnabled();

  /// The current permission state without prompting the user.
  Future<LocationPermissionState> checkPermission();

  /// Requests the location permission, prompting the user when needed.
  Future<LocationPermissionState> requestPermission();

  /// Starts a stream of GPS fixes.
  Stream<LocationFix> watch(LocationTrackingOptions options);

  /// Returns the current position once, or `null` when unavailable.
  Future<LocationFix?> currentPosition();

  /// Opens the OS settings page where location permissions can be changed.
  Future<bool> openApplicationSettings();

  /// Releases any resource held by the service.
  void dispose();
}
