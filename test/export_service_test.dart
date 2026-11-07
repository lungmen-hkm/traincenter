import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traincenter/core/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.previx.traincenter/downloads');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('sends the PNG to the native Downloads saver', () async {
    final bytes = Uint8List.fromList(<int>[0x89, 0x50, 0x4e, 0x47]);
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return 'Downloads/morning_ride_123.png';
    });

    final service = ActivityExportService();
    final location = await service.savePngToDownloads(
      bytes,
      activityName: 'Morning Ride',
    );

    expect(location, 'Downloads/morning_ride_123.png');
    expect(received?.method, 'savePngToDownloads');

    final arguments = received!.arguments as Map<Object?, Object?>;
    expect(arguments['bytes'], orderedEquals(bytes));
    expect(arguments['fileName'], matches(RegExp(r'^morning_ride_\d+\.png$')));
  });

  test('rejects an empty location returned by the native layer', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => '');
    final service = ActivityExportService();

    await expectLater(
      service.savePngToDownloads(
        Uint8List.fromList(<int>[1, 2, 3]),
        activityName: 'Ride',
      ),
      throwsStateError,
    );
  });
}
