import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../utils/format.dart';
import '../widgets/add_trip_sheet.dart';
import '../widgets/day_switcher.dart';
import '../widgets/summary_card.dart';
import '../widgets/trip_tile.dart';

/// The only screen: day switcher, summary card and the list of trips.
class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  List<String> _days = const [];
  String? _selectedDay;
  DaySummary? _summary;
  List<Trip> _trips = const [];
  bool _loading = true;
  String? _error;

  /// Increases with every load; responses of older loads are ignored, so
  /// fast day switching never shows a stale day.
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reloads the list of days and then [day] (default: the selected day,
  /// or the latest day with trips on first start).
  Future<void> _load({String? day}) async {
    final loadId = ++_loadId;
    setState(() {
      if (day != null && day != _selectedDay) {
        // Show the new date right away and do not leave the old day's numbers under it.
        _selectedDay = day;
        _summary = null;
        _trips = const [];
      }
      _loading = true;
      _error = null;
    });
    try {
      final days = await widget.api.getDays();
      final target = day ??
          _selectedDay ??
          (days.isNotEmpty ? days.last : toDayKey(toAlmaty(DateTime.now())));
      final results = await Future.wait([widget.api.getSummary(target), widget.api.getTrips(target)]);
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _days = days;
        _selectedDay = target;
        _summary = results[0] as DaySummary;
        _trips = results[1] as List<Trip>;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || loadId != _loadId) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _addTrip() async {
    final result = await showModalBottomSheet<CreateTripResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: AddTripSheet(api: widget.api, day: _selectedDay ?? toDayKey(toAlmaty(DateTime.now()))),
      ),
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.created ? 'Поездка добавлена' : 'Такая поездка уже есть'),
    ));
    await _load(day: result.trip.day);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _selectedDay;
    return Scaffold(
      appBar: AppBar(title: const Text('Дневник смен'), centerTitle: true),
      // Hidden until the first successful load: there is no day to add to yet.
      floatingActionButton: selectedDay == null
          ? null
          : FloatingActionButton(
              tooltip: 'Добавить поездку',
              onPressed: _addTrip,
              child: const Icon(Icons.add),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              if (selectedDay != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DaySwitcher(
                    days: _days,
                    selected: selectedDay,
                    onChanged: (day) => _load(day: day),
                  ),
                ),
              if (_loading) const LinearProgressIndicator(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _buildContent(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _summary;
    const padding = EdgeInsets.fromLTRB(16, 8, 16, 88); // room for the FAB

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          const SizedBox(height: 48),
          Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ),
        ],
      );
    }
    if (summary == null) {
      // First load is still running; the progress bar above shows it.
      return ListView(physics: const AlwaysScrollableScrollPhysics());
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        SummaryCard(summary: summary),
        const SizedBox(height: 8),
        if (_trips.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text('Поездок нет', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          )
        else
          for (final trip in _trips) TripTile(trip: trip),
      ],
    );
  }
}
