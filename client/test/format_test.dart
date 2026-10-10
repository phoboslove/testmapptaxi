import 'package:driver_diary/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  group('formatMoney', () {
    test('groups thousands with spaces and puts ₸ after the number', () {
      expect(formatMoney(2400), '2 400 ₸');
      expect(formatMoney(21760), '21 760 ₸');
      expect(formatMoney(1234567), '1 234 567 ₸');
    });

    test('small numbers and zero have no separator', () {
      expect(formatMoney(0), '0 ₸');
      expect(formatMoney(800), '800 ₸');
    });

    test('negative amount keeps the sign', () {
      expect(formatMoney(-1500), '−1 500 ₸');
    });
  });

  group('formatDuration', () {
    test('minutes under an hour', () {
      expect(formatDuration(const Duration(minutes: 22)), '22 мин');
    });

    test('hours and minutes', () {
      expect(formatDuration(const Duration(minutes: 65)), '1 ч 05 мин');
      expect(formatDuration(const Duration(hours: 2)), '2 ч');
    });
  });

  group('Almaty time', () {
    test('a UTC moment is shown in Almaty wall-clock time', () {
      final t = toAlmaty(DateTime.parse('2026-10-03T19:30:00Z'));
      expect(toDayKey(t), '2026-10-04');
      expect(formatTime(t), '00:30');
    });

    test('wall-clock time is sent with +05:00', () {
      expect(toApiIso(DateTime.utc(2026, 10, 1, 8, 10)), '2026-10-01T08:10:00+05:00');
    });
  });

  test('day title in Russian', () {
    expect(formatDayTitle(parseDayKey('2026-10-01')), 'Чт, 1 октября');
  });

  test('trips count is declined', () {
    expect(tripsCountLabel(1), '1 поездка');
    expect(tripsCountLabel(3), '3 поездки');
    expect(tripsCountLabel(8), '8 поездок');
    expect(tripsCountLabel(11), '11 поездок');
    expect(tripsCountLabel(22), '22 поездки');
  });
}
