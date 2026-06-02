import 'package:flutter_test/flutter_test.dart';
import 'package:drunken_sailor/domain/models/bar.dart';
import 'package:drunken_sailor/domain/models/opening_hours.dart';

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
      final bar = _bar(hours: {'monday': _h(960, 1380)});
      expect(bar.isOpenAt(DateTime(2024, 1, 1, 20, 0)), isTrue);
    });

    test('closed before opening', () {
      final bar = _bar(hours: {'monday': _h(960, 1380)});
      expect(bar.isOpenAt(DateTime(2024, 1, 1, 14, 0)), isFalse);
    });

    test('closed after closing', () {
      final bar = _bar(hours: {'monday': _h(960, 1380)});
      expect(bar.isOpenAt(DateTime(2024, 1, 1, 23, 30)), isFalse);
    });

    test('closed day returns false', () {
      final bar = _bar(hours: {'tuesday': _h(960, 1380)});
      expect(bar.isOpenAt(DateTime(2024, 1, 1, 20, 0)), isFalse);
    });

    test('open past midnight — during evening portion', () {
      final bar = _bar(hours: {'friday': _h(1320, 240)});
      expect(bar.isOpenAt(DateTime(2024, 1, 5, 23, 0)), isTrue);
    });

    test('open past midnight — during early morning portion', () {
      final bar = _bar(hours: {'friday': _h(1320, 240)});
      expect(bar.isOpenAt(DateTime(2024, 1, 6, 2, 0)), isTrue);
    });

    test('open past midnight — closed after cutoff', () {
      final bar = _bar(hours: {'friday': _h(1320, 240)});
      expect(bar.isOpenAt(DateTime(2024, 1, 6, 5, 0)), isFalse);
    });

    test('Sunday 03:00 — open from Saturday night', () {
      final bar = _bar(hours: {'saturday': _h(840, 180)});
      expect(bar.isOpenAt(DateTime(2024, 1, 7, 2, 0)), isTrue);
    });

    test('Monday 14:00 — open', () {
      final bar = _bar(hours: {'monday': _h(840, 1380)});
      expect(bar.isOpenAt(DateTime(2024, 1, 1, 14, 0)), isTrue);
    });
  });

  group('distanceTo (Haversine)', () {
    test('same location returns 0', () {
      final bar = _bar();
      expect(bar.distanceTo(52.7897, 6.8942), equals(0));
    });

    test('known distance: Emmen to Amsterdam ~142km crow-flies', () {
      final bar = _bar();
      final distM = bar.distanceTo(52.3676, 4.9041);
      expect(distM, greaterThan(135000));
      expect(distM, lessThan(155000));
    });

    test('short distance within city is reasonable', () {
      final bar = _bar();
      final distM = bar.distanceTo(52.7900, 6.8950);
      expect(distM, greaterThan(50));
      expect(distM, lessThan(150));
    });

    test('returns integer meters', () {
      final bar = _bar();
      expect(bar.distanceTo(52.3676, 4.9041), isA<int>());
    });
  });

  group('Bar serialization round-trip', () {
    test('toJson → fromJson preserves all fields', () {
      final original = Bar(
        id: 'bar_1',
        name: 'Test Café',
        latitude: 52.7897,
        longitude: 6.8942,
        gayFriendly: true,
        hours: {'monday': _h(960, 1380), 'friday': _h(960, 180)},
        isBlacklisted: false,
      );
      final json = original.toJson();
      final restored = Bar.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.latitude, equals(original.latitude));
      expect(restored.longitude, equals(original.longitude));
      expect(restored.gayFriendly, equals(original.gayFriendly));
      expect(restored.hours['monday']?.opens, equals(960));
      expect(restored.hours['monday']?.closes, equals(1380));
      expect(restored.hours['friday']?.closes, equals(180));
    });
  });
}
