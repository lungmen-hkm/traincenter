import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the device screen awake while a recording is running.
///
/// The implementation is a thin wrapper around the native
/// `FLAG_KEEP_SCREEN_ON` window flag, exposed through a method channel
/// declared in `MainActivity.kt`. Doing it this way avoids pulling in an
/// extra plugin for a two line feature.
abstract final class ScreenWakeLock {
  /// Name of the method channel shared with the Android host.
  static const String _channelName = 'com.previx.traincenter/wakelock';

  static const MethodChannel _channel = MethodChannel(_channelName);

  /// Whether the screen is currently kept awake.
  static bool _enabled = false;

  /// Prevents the screen from dimming while [enabled] is `true`.
  ///
  /// Calling the method twice with the same value is a no-op.
  static Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;

    try {
      await _channel.invokeMethod<void>(
        'setEnabled',
        <String, Object?>{'enabled': enabled},
      );
    } on MissingPluginException {
      // The channel is only implemented on Android. On the other platforms
      // the screen simply dims as usual.
      _enabled = false;
    } on PlatformException catch (error) {
      debugPrint('TrainCenter: unable to change the screen wake lock: $error');
      _enabled = false;
    }
  }
}
