import 'package:flutter/material.dart';

import '../utils/format.dart';

/// "‹  Чт, 1 октября  ›". Arrows move between days that have trips;
/// tapping the title opens the list of those days.
class DaySwitcher extends StatelessWidget {
  const DaySwitcher({super.key, required this.days, required this.selected, required this.onChanged});

  final List<String> days; // sorted "YYYY-MM-DD"
  final String selected;
  final ValueChanged<String> onChanged;

  String? get _previous {
    final earlier = days.where((d) => d.compareTo(selected) < 0);
    return earlier.isEmpty ? null : earlier.last;
  }

  String? get _next {
    final later = days.where((d) => d.compareTo(selected) > 0);
    return later.isEmpty ? null : later.first;
  }

  Future<void> _pickDay(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Дни со сменами'),
        children: [
          for (final day in days.reversed)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, day),
              child: Text(
                formatDayTitle(parseDayKey(day)),
                style: day == selected ? const TextStyle(fontWeight: FontWeight.bold) : null,
              ),
            ),
        ],
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    final next = _next;
    return Row(
      children: [
        IconButton(
          tooltip: 'Предыдущий день',
          icon: const Icon(Icons.chevron_left),
          onPressed: previous == null ? null : () => onChanged(previous),
        ),
        Expanded(
          child: TextButton(
            onPressed: days.isEmpty ? null : () => _pickDay(context),
            child: Text(
              formatDayTitle(parseDayKey(selected)),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Следующий день',
          icon: const Icon(Icons.chevron_right),
          onPressed: next == null ? null : () => onChanged(next),
        ),
      ],
    );
  }
}
