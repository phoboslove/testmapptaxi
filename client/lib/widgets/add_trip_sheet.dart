import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../utils/format.dart';

/// Bottom-sheet form for a new trip. Pops with a [CreateTripResult] on success.
///
/// The trip id is generated once when the form opens and reused for every
/// "Save" tap, so retrying after a network failure cannot create a duplicate.
class AddTripSheet extends StatefulWidget {
  const AddTripSheet({super.key, required this.api, required this.day});

  final ApiClient api;
  final String day; // default date of the trip

  @override
  State<AddTripSheet> createState() => _AddTripSheetState();
}

class _AddTripSheetState extends State<AddTripSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _commission = TextEditingController();
  final String _id = const Uuid().v4();

  late DateTime _start; // Almaty wall clock, minutes precision
  late DateTime _end;
  String _payment = 'card';
  bool _commissionEdited = false;
  bool _saving = false;
  String? _timeError;
  String? _formError;
  Map<String, String> _serverErrors = const {};

  @override
  void initState() {
    super.initState();
    final now = toAlmaty(DateTime.now());
    final day = parseDayKey(widget.day);
    _start = DateTime.utc(day.year, day.month, day.day, now.hour, now.minute - now.minute % 5);
    _end = _start.add(const Duration(minutes: 20));
    _amount.addListener(_suggestCommission);
  }

  @override
  void dispose() {
    _amount.dispose();
    _commission.dispose();
    super.dispose();
  }

  /// Fill in 15% of the amount until the commission is edited by hand.
  void _suggestCommission() {
    if (_commissionEdited) return;
    final amount = int.tryParse(_amount.text);
    _commission.text = amount == null ? '' : '${amount * 15 ~/ 100}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _setTime(isStart, DateTime.utc(picked.year, picked.month, picked.day, current.hour, current.minute));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    _setTime(isStart, DateTime.utc(current.year, current.month, current.day, picked.hour, picked.minute));
  }

  void _setTime(bool isStart, DateTime value) {
    setState(() {
      if (isStart) {
        final length = _end.difference(_start);
        _start = value;
        // Keep the trip length when the start moves forward past the end.
        if (!_end.isAfter(_start)) _end = _start.add(length.isNegative ? const Duration(minutes: 20) : length);
      } else {
        _end = value;
      }
      _timeError = null;
      _serverErrors = const {};
    });
  }

  String? _validateAmount(String? text) {
    final amount = int.tryParse(text ?? '');
    if (amount == null) return 'Введите сумму';
    if (amount <= 0) return 'Сумма должна быть больше 0';
    return null;
  }

  String? _validateCommission(String? text) {
    final commission = int.tryParse(text ?? '');
    if (commission == null) return 'Введите комиссию';
    final amount = int.tryParse(_amount.text);
    if (amount != null && commission > amount) return 'Комиссия больше суммы';
    return null;
  }

  Future<void> _save() async {
    final fieldsValid = _formKey.currentState!.validate();
    final timeValid = _end.isAfter(_start);
    setState(() {
      _timeError = timeValid ? null : 'Окончание должно быть позже начала';
      _formError = null;
      _serverErrors = const {};
    });
    if (!fieldsValid || !timeValid) return;

    setState(() => _saving = true);
    try {
      final result = await widget.api.createTrip(NewTrip(
        id: _id,
        start: _start,
        end: _end,
        amount: int.parse(_amount.text),
        payment: _payment,
        commission: int.parse(_commission.text),
      ));
      if (mounted) Navigator.pop(context, result);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverErrors = error.fieldErrors;
        // Errors that belong to a visible field are shown under it; anything
        // else (409, network, unknown field) goes to the bottom of the form.
        const shownUnderFields = {'start', 'end', 'amount', 'commission'};
        final hasOnlyFieldErrors = error.fieldErrors.isNotEmpty &&
            error.fieldErrors.keys.every(shownUnderFields.contains);
        _formError = hasOnlyFieldErrors ? null : error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeError = _timeError ?? _serverErrors['end'] ?? _serverErrors['start'];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Новая поездка', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              _DateTimeRow(
                label: 'Начало',
                value: _start,
                onPickDate: () => _pickDate(isStart: true),
                onPickTime: () => _pickTime(isStart: true),
              ),
              const SizedBox(height: 8),
              _DateTimeRow(
                label: 'Окончание',
                value: _end,
                onPickDate: () => _pickDate(isStart: false),
                onPickTime: () => _pickTime(isStart: false),
              ),
              if (timeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(timeError, style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Сумма', suffixText: '₸', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                validator: _validateAmount,
                forceErrorText: _serverErrors['amount'],
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commission,
                decoration: const InputDecoration(
                  labelText: 'Комиссия',
                  suffixText: '₸',
                  helperText: 'По умолчанию 15% от суммы',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                validator: _validateCommission,
                forceErrorText: _serverErrors['commission'],
                onChanged: (_) => _commissionEdited = true,
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Наличные'), icon: Icon(Icons.payments)),
                  ButtonSegment(value: 'card', label: Text('Карта'), icon: Icon(Icons.credit_card)),
                ],
                selected: {_payment},
                onSelectionChanged: (value) => setState(() => _payment = value.first),
              ),
              if (_formError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_formError!, style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.value,
    required this.onPickDate,
    required this.onPickTime,
  });

  final String label;
  final DateTime value;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label)),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(formatLongDate(value)),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onPickTime,
          icon: const Icon(Icons.schedule, size: 18),
          label: Text(formatTime(value)),
        ),
      ],
    );
  }
}
