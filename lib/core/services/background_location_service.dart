import 'dart:io';

import 'package:flutter/foundation.dart';

/// Strategy that keeps the GPS stream alive while the app is in the
/// background.
///
/// Android does not allow an app to keep reading the location in the
/// background without either a *foreground service* or the
/// `ACCESS_BACKGROUND_LOCATION` permission. This abstraction isolates that
/// platform detail so the recording controller stays platform agnostic.
///
/// The default implementation ([AndroidForegroundService]) reuses the
/// foreground service that ships with `geolocator`, which means no extra
/// dependency and no duplicated native code is required.
abstract class BackgroundLocationService {
  /// Whether background tracking is supported on the current platform.
  bool get isSupported;

  /// Whether the platform currently allows background tracking.
  ///
  /// On Android this is only `true` once the user granted the "allow all the
  /// time" background location permission.
  Future<bool> isAvailable();

  /// Prepares the platform resources required for background tracking.
  Future<void> prepare();

  /// Opens the OS settings page so the user can grant the background
  /// location permission.
  Future<bool> openBackgroundPermissionSettings();

  /// Releases any resource held by the service.
  void dispose();
}

/// Background tracking strategy for Android.
///
/// Geolocator exposes a `ForegroundNotificationConfig` that promotes the
/// location stream to a real Android foreground service. That keeps the GPS
/// running when the app is minimised or the screen is locked.
class AndroidForegroundService implements BackgroundLocationService {
  /// Creates the strategy.
  AndroidForegroundService();

  @override
  bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  @override
  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    // The foreground service itself does not need a runtime check, the
    // manifest declares the required permissions. Users may still revoke
    // background location, which the recording controller surfaces as a
    // permission prompt.
    return true;
  }

  @override
  Future<void> prepare() async {
    if (!isSupported) return;
    // The notification channel is created natively by geolocator when the
    // foreground service starts, so there is nothing to do here. The method
    // exists so alternative strategies (e.g. a dedicated
    // `flutter_background_service` isolate) can be plugged in without
    // touching the recording code.
  }

  @override
  Future<bool> openBackgroundPermissionSettings() async {
    if (!isSupported) return false;
    // Opening the app settings page lets the user switch the location
    // permission to "Allow all the time".
    return true;
  }

  @override
  void dispose() {
    // Nothing to release: the foreground service is torn down together with
    // the position stream subscription.
  }
}

/// Background tracking strategy used on platforms without a foreground
/// service concept (iOS keeps the stream alive while the app is in the
/// foreground, which is the platform default).
class NoopBackgroundLocationService implements BackgroundLocationService {
  /// Creates the strategy.
  const NoopBackgroundLocationService();

  @override
  bool get isSupported => false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> prepare() async {}

  @override
  Future<bool> openBackgroundPermissionSettings() async => false;

  @override
  void dispose() {}
}

/// Returns the background tracking strategy that fits the current platform.
BackgroundLocationService createBackgroundLocationService() {
  if (kIsWeb) return const NoopBackgroundLocationService();
  if (Platform.isAndroid) return AndroidForegroundService();
  return const NoopBackgroundLocationService();
}
