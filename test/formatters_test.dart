import 'package:flutter_test/flutter_test.dart';
import 'package:traincenter/core/utils/formatters.dart';

void main() {
  test('pace rounds before splitting minutes and seconds', () {
    // 1000 / 299.7 rounds to 300 seconds, which must become 5:00 rather than
    // the invalid 4:60.
    expect(Formatters.pace(1000 / 299.7, UnitSystem.metric), '5:00 /km');
  });

  test('pace uses the unit suffix and handles a standstill', () {
    expect(Formatters.pace(0, UnitSystem.metric), '--:-- /km');
    expect(Formatters.pace(0, UnitSystem.imperial), '--:-- /mi');
    expect(Formatters.pace(1000 / 240, UnitSystem.metric), '4:00 /km');
  });

  test('file sizes use binary units', () {
    expect(Formatters.fileSize(512), '512 B');
    expect(Formatters.fileSize(2048), '2.0 KB');
    expect(Formatters.fileSize(2 * 1024 * 1024), '2.0 MB');
  });
}
