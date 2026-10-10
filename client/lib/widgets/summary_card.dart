import 'package:flutter/material.dart';

import '../api/models.dart';
import '../utils/format.dart';

/// "На руки" is the biggest number on the screen; the rest is small print.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: colors.onPrimaryContainer.withValues(alpha: 0.75));

    return Card(
      color: colors.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('На руки', style: theme.textTheme.titleMedium?.copyWith(color: colors.onPrimaryContainer)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(summary.net),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Выручка ${formatMoney(summary.revenue)} · '
              'Комиссия ${formatMoney(summary.commission)} · '
              '${tripsCountLabel(summary.tripsCount)}',
              style: muted,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PaymentBlock(icon: Icons.payments, label: 'Наличные', totals: summary.cash),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PaymentBlock(icon: Icons.credit_card, label: 'Карта', totals: summary.card),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentBlock extends StatelessWidget {
  const _PaymentBlock({required this.icon, required this.label, required this.totals});

  final IconData icon;
  final String label;
  final PaymentTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(
                  '${formatMoney(totals.amount)} · ${totals.count}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
