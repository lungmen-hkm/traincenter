import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Requests the Android 13+ notification permission used by the foreground
/// tracking service.
///
/// Android 13 hides foreground-service notifications unless the app holds
/// `POST_NOTIFICATIONS`. The permission is requested right before background
/// tracking starts so that the system prompt has context. A denial never
/// blocks the recording: the service keeps running and only its ongoing
/// notification is hidden.
abstract final class NotificationPermission {
  /// Name of the method channel implemented in `MainActivity.kt`.
  static const String _channelName = 'com.previx.traincenter/permissions';

  static const MethodChannel _channel = MethodChannel(_channelName);

  /// Returns whether notifications may be posted.
  ///
  /// On platforms without the native channel (iOS, tests) this reports `true`.
  /// The Android side reports `true` for versions below 13, where the
  /// permission does not exist.
  static Future<bool> requestIfNeeded() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return granted ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException catch (error) {
      debugPrint(
        'TrainCenter: unable to request notification permission: $error',
      );
      return false;
    }
  }
}
