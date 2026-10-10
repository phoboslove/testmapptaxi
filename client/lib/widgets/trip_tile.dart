import 'package:flutter/material.dart';

import '../api/models.dart';
import '../utils/format.dart';

/// "08:10–08:32 · 22 мин", amount on the right, commission in grey.
class TripTile extends StatelessWidget {
  const TripTile({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        trip.isCash ? Icons.payments : Icons.credit_card,
        color: theme.colorScheme.primary,
        semanticLabel: trip.isCash ? 'Наличные' : 'Карта',
      ),
      title: Text('${formatTime(trip.start)}–${formatTime(trip.end)} · ${formatDuration(trip.duration)}'),
      subtitle: trip.endsNextDay
          ? Text('→ ${formatTime(trip.end)} след. дня', style: TextStyle(color: theme.colorScheme.tertiary))
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatMoney(trip.amount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(
            'комиссия ${formatMoney(trip.commission)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
