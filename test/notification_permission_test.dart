import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traincenter/core/services/notification_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.previx.traincenter/permissions');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('requests the native permission and reports a grant', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });

    expect(await NotificationPermission.requestIfNeeded(), isTrue);
    expect(calls, <String>['requestNotificationPermission']);
  });

  test('reports a denied notification permission', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => false);

    expect(await NotificationPermission.requestIfNeeded(), isFalse);
  });

  test('a missing native implementation does not block recording', () async {
    expect(await NotificationPermission.requestIfNeeded(), isTrue);
  });
}
