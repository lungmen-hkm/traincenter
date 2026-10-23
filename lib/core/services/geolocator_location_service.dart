import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

/// [LocationService] implementation backed by the `geolocator` plugin.
///
/// The plugin is used as a *transport* only: all of the domain logic
/// (distance accumulation, moving time, elevation) lives in the recording
/// controller, and all plugin types are translated into [LocationFix].
class GeolocatorLocationService implements LocationService {
  /// Creates the service.
  GeolocatorLocationService();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermissionState> checkPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionState.serviceDisabled;
    }
    final permission = await Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  @override
  Future<LocationPermissionState> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionState.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _mapPermission(permission);
  }

  @override
  Stream<LocationFix> watch(LocationTrackingOptions options) {
    final settings = _buildSettings(options);
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        speedMps: position.speed,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      ),
    );
  }

  @override
  Future<LocationFix?> currentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _buildSettings(
          const LocationTrackingOptions(interval: Duration(seconds: 1)),
        ),
      );
      return LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        speedMps: position.speed,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('TrainCenter: unable to resolve current position: $error');
      assert(() {
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
      return null;
    }
  }

  @override
  Future<LocationFix?> lastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      return LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        speedMps: position.speed,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
    } on Object catch (error, stackTrace) {
      // No permission yet or no cached fix available: the caller simply keeps
      // the default map centre.
      debugPrint('TrainCenter: unable to read last known position: $error');
      assert(() {
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
      return null;
    }
  }

  @override
  Future<bool> openApplicationSettings() => Geolocator.openAppSettings();

  @override
  void dispose() {
    // The geolocator position stream is closed by cancelling the
    // subscription held by the recording controller.
  }

  /// Builds the platform specific settings for a GPS stream.
  ///
  /// On Android, providing a [ForegroundNotificationConfig] turns the
  /// location stream into a foreground service, which is what allows the
  /// recording to continue while the app is backgrounded.
  LocationSettings _buildSettings(LocationTrackingOptions options) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: options.distanceFilterMeters,
      );
    }

    // Use Android's native `LocationManager` (GNSS) instead of the Google Play
    // Services fused provider. TrainCenter is a fully offline app: it must not
    // depend on Play Services being installed or working, and it should not
    // route location through a third-party service. The native provider is
    // also the one fed by the emulator's `geo fix` command.
    return AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: options.distanceFilterMeters,
      intervalDuration: options.interval,
      forceLocationManager: true,
      foregroundNotificationConfig: options.allowBackground
          ? ForegroundNotificationConfig(
              notificationTitle: options.notificationTitle,
              notificationText: options.notificationText,
              notificationChannelName: 'TrainCenter tracking',
              enableWakeLock: true,
              setOngoing: true,
            )
          : null,
    );
  }

  /// Translates a plugin permission into the domain enum.
  LocationPermissionState _mapPermission(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        LocationPermissionState.granted,
      LocationPermission.denied => LocationPermissionState.denied,
      LocationPermission.deniedForever => LocationPermissionState.deniedForever,
      LocationPermission.unableToDetermine => LocationPermissionState.denied,
    };
  }
}
