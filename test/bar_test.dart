import 'package:flutter_test/flutter_test.dart';
import 'package:drunken_sailor/models/bar.dart';

Bar _bar({Map<String, OpeningHours> hours = const {}}) => Bar(
      id: 'test',
      name: 'Test Bar',
      latitude: 52.7897,
      longitude: 6.8942,
      hours: hours,
    );

OpeningHours _h(int opens, int closes) =>
    OpeningHours(opens: opens, closes: closes);

void main() {
  group('isOpenAt', () {
    test('open during normal hours', () {
      final bar = _bar(hours: {'monday': _h(960, 1380)}); // 16:00–23:00
      expect(bar.isOpenAt(DateTime(2024, 1, 1, 20, 0)), isTrue); // Monday 20:00
    });

    test('closed before opening', () {
      final bar = _bar(hours: {'monday': _h(960, 1380)});
      expect(bar.isOpenAt(DateTime(2024, 1, 1, 14, 0)), isFalse); // 14:00
    });

    test('closed after closing', () {
      final bar = _bar(hours: {'monday': _h(960, 1380)});
      expect(bar.isOpenAt(DateTime(2024, 1, 1, 23, 30)), isFalse); // 23:30
    });

    test('closed day returns false', () {
      final bar = _bar(hours: {'tuesday': _h(960, 1380)});
      expect(bar.isOpenAt(DateTime(2024, 1, 1, 20, 0)), isFalse); // Monday, no entry
    });

    test('open past midnight — during evening portion', () {
      final bar = _bar(hours: {'friday': _h(1320, 240)}); // 22:00–04:00
      expect(bar.isOpenAt(DateTime(2024, 1, 5, 23, 0)), isTrue); // Friday 23:00
    });

    test('open past midnight — during early morning portion', () {
      final bar = _bar(hours: {'friday': _h(1320, 240)}); // 22:00–04:00
      // Saturday 02:00 should still be "open" from Friday
      expect(bar.isOpenAt(DateTime(2024, 1, 6, 2, 0)), isTrue);
    });

    test('open past midnight — closed after cutoff', () {
      final bar = _bar(hours: {'friday': _h(1320, 240)}); // 22:00–04:00
      expect(bar.isOpenAt(DateTime(2024, 1, 6, 5, 0)), isFalse); // Saturday 05:00
    });

    test('Sunday 03:00 — open from Saturday night', () {
      final bar = _bar(hours: {'saturday': _h(840, 180)}); // 14:00–03:00
      expect(bar.isOpenAt(DateTime(2024, 1, 7, 2, 0)), isTrue); // Sunday 02:00
    });

    test('Monday 14:00 — open', () {
      final bar = _bar(hours: {'monday': _h(840, 1380)}); // 14:00–23:00
      expect(bar.isOpenAt(DateTime(2024, 1, 1, 14, 0)), isTrue);
    });
  });

  group('distanceTo (Haversine)', () {
    test('same location returns 0', () {
      final bar = _bar();
      expect(bar.distanceTo(52.7897, 6.8942), equals(0));
    });

    test('known distance: Emmen to Amsterdam ~175km', () {
      final bar = _bar(); // 52.7897, 6.8942 (Emmen)
      final distM = bar.distanceTo(52.3676, 4.9041); // Amsterdam
      expect(distM, greaterThan(170000));
      expect(distM, lessThan(180000));
    });

    test('short distance within city is reasonable', () {
      final bar = _bar(); // 52.7897, 6.8942
      final distM = bar.distanceTo(52.7900, 6.8950); // ~80m away
      expect(distM, greaterThan(50));
      expect(distM, lessThan(150));
    });

    test('returns integer meters', () {
      final bar = _bar();
      final result = bar.distanceTo(52.3676, 4.9041);
      expect(result, isA<int>());
    });
  });
}
