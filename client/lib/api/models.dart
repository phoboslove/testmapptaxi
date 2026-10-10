import '../utils/format.dart';

class Trip {
  const Trip({
    required this.id,
    required this.start,
    required this.end,
    required this.amount,
    required this.payment,
    required this.commission,
    required this.day,
  });

  final String id;

  /// Almaty wall-clock times (see [toAlmaty]).
  final DateTime start;
  final DateTime end;
  final int amount;
  final String payment; // "cash" | "card"
  final int commission;
  final String day; // "YYYY-MM-DD"

  bool get isCash => payment == 'cash';
  Duration get duration => end.difference(start);
  bool get endsNextDay => toDayKey(end) != toDayKey(start);

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        start: toAlmaty(DateTime.parse(json['start'] as String)),
        end: toAlmaty(DateTime.parse(json['end'] as String)),
        amount: json['amount'] as int,
        payment: json['payment'] as String,
        commission: json['commission'] as int,
        day: json['day'] as String,
      );
}

/// What the form sends to POST /api/trips.
class NewTrip {
  const NewTrip({
    required this.id,
    required this.start,
    required this.end,
    required this.amount,
    required this.payment,
    required this.commission,
  });

  final String id;
  final DateTime start; // Almaty wall clock
  final DateTime end;
  final int amount;
  final String payment;
  final int commission;

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': toApiIso(start),
        'end': toApiIso(end),
        'amount': amount,
        'payment': payment,
        'commission': commission,
      };
}

class PaymentTotals {
  const PaymentTotals({required this.amount, required this.count});

  final int amount;
  final int count;

  factory PaymentTotals.fromJson(Map<String, dynamic> json) =>
      PaymentTotals(amount: json['amount'] as int, count: json['count'] as int);
}

class DaySummary {
  const DaySummary({
    required this.date,
    required this.tripsCount,
    required this.revenue,
    required this.commission,
    required this.net,
    required this.cash,
    required this.card,
  });

  final String date;
  final int tripsCount;
  final int revenue;
  final int commission;
  final int net;
  final PaymentTotals cash;
  final PaymentTotals card;

  factory DaySummary.fromJson(Map<String, dynamic> json) => DaySummary(
        date: json['date'] as String,
        tripsCount: json['trips_count'] as int,
        revenue: json['revenue'] as int,
        commission: json['commission'] as int,
        net: json['net'] as int,
        cash: PaymentTotals.fromJson(json['cash'] as Map<String, dynamic>),
        card: PaymentTotals.fromJson(json['card'] as Map<String, dynamic>),
      );
}
