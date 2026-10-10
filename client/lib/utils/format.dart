import 'package:intl/intl.dart';

/// Almaty is UTC+05:00. Like the server, the client uses a fixed offset,
/// so times look the same whatever time zone the device is set to.
const almatyOffset = Duration(hours: 5);

/// Wall-clock time in Almaty. The returned value is flagged as UTC only so
/// that its fields (hour, day, ...) are not shifted by the device time zone.
DateTime toAlmaty(DateTime moment) => moment.toUtc().add(almatyOffset);

/// ISO 8601 string with +05:00 for an Almaty wall-clock time.
String toApiIso(DateTime almatyWallClock) {
  final t = almatyWallClock;
  return '${_four(t.year)}-${_two(t.month)}-${_two(t.day)}'
      'T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}+05:00';
}

/// "YYYY-MM-DD" of a date.
String toDayKey(DateTime date) => '${_four(date.year)}-${_two(date.month)}-${_two(date.day)}';

/// Date from "YYYY-MM-DD", as a UTC-flagged wall-clock value.
DateTime parseDayKey(String day) => DateTime.parse('${day}T00:00:00Z');

const _nbsp = ' ';

/// 2400 -> "2 400 ₸" (non-breaking spaces, so the amount never wraps).
String formatMoney(int amount) {
  final digits = amount.abs().toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    groups.insert(0, digits.substring(end - 3 < 0 ? 0 : end - 3, end));
  }
  return '${amount < 0 ? '−' : ''}${groups.join(_nbsp)}$_nbsp₸';
}

/// 22 min -> "22 мин", 65 min -> "1 ч 05 мин".
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return '$minutes мин';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} ч' : '${minutes ~/ 60} ч ${_two(rest)} мин';
}

/// "08:10"
String formatTime(DateTime wallClock) => '${_two(wallClock.hour)}:${_two(wallClock.minute)}';

/// "Чт, 1 октября". Needs initializeDateFormatting('ru').
String formatDayTitle(DateTime date) {
  final text = DateFormat('EE, d MMMM', 'ru').format(date);
  return text[0].toUpperCase() + text.substring(1);
}

/// "1 октября 2026"
String formatLongDate(DateTime date) => DateFormat('d MMMM y', 'ru').format(date);

/// 1 поездка, 2 поездки, 5 поездок.
String tripsCountLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'поездка'
      : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
          ? 'поездки'
          : 'поездок';
  return '$count $word';
}

String _two(int value) => value.toString().padLeft(2, '0');
String _four(int value) => value.toString().padLeft(4, '0');
