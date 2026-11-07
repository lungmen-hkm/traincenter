import 'package:flutter_test/flutter_test.dart';
import 'package:traincenter/core/services/offline_tiles.dart';

void main() {
  test('ignores the README and other non-PNG assets', () {
    expect(
      OfflineTiles.containsTiles(<String>[
        'assets/maptiles/README.md',
        'assets/other/image.png',
      ]),
      isFalse,
    );
  });

  test('detects PNG tiles below the maptiles prefix', () {
    expect(
      OfflineTiles.containsTiles(<String>[
        'assets/maptiles/README.md',
        'assets/maptiles/14/13475/8584.png',
      ]),
      isTrue,
    );
  });
}
