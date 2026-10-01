import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/alert.dart';
import '../../domain/instrument.dart';
import '../../providers/alert_actions.dart';
import '../../providers/market_providers.dart';
import '../../theme.dart';

/// Create or edit an alert for [instrument].
/// Multi-condition: each row is a condition; AND/OR applies across all rows.
class AlertEditScreen extends ConsumerStatefulWidget {
  const AlertEditScreen({super.key, required this.instrument, this.existing});

  final Instrument instrument;
  final Alert? existing;

  @override
  ConsumerState<AlertEditScreen> createState() => _AlertEditScreenState();
}

class _AlertEditScreenState extends ConsumerState<AlertEditScreen> {
  final _nameController = TextEditingController();
  Logic _logic = Logic.all;
  AlertMode _mode = AlertMode.once;
  int _cooldownMinutes = 0;
  bool _enabled = true;
  DateTime? _expiresAt;
  bool _busy = false;

  final List<_ConditionRow> _rows = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name ?? '';
      _logic = existing.logic;
      _mode = existing.mode;
      _cooldownMinutes = existing.cooldownMinutes;
      _enabled = existing.enabled;
      _expiresAt = existing.expiresAt;
      for (final c in existing.conditions) {
        _rows.add(_ConditionRow.fromCondition(c));
      }
    }
    if (_rows.isEmpty) _rows.add(_ConditionRow());
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  bool get _canSave =>
      _rows.isNotEmpty && _rows.every((r) => r.isValid);

  Future<void> _save() async {
    if (!_canSave || _busy) return;
    setState(() => _busy = true);
    try {
      await createAlert(
        ref,
        instrument: widget.instrument,
        name: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        conditions: _rows.map((r) => r.toCondition()).toList(),
        logic: _logic,
        mode: _mode,
        cooldownMinutes: _mode == AlertMode.repeating ? _cooldownMinutes : 0,
        enabled: _enabled,
        expiresAt: _expiresAt,
        referencePrice: _needsReferencePrice
            ? ref
                .read(quoteStreamProvider(widget.instrument.symbol))
                .value
                ?.price
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alert created for ${widget.instrument.symbol}')),
      );
      Navigator.of(context)..pop()..pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _needsReferencePrice =>
      _rows.any((r) => r.type == ConditionType.changePercentAbove);

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expiresAt ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _expiresAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null
            ? 'New alert · ${widget.instrument.symbol}'
            : 'Edit alert'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Optional name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Alert name (optional)',
              hintText: 'e.g. Gold breakout',
            ),
          ),
          const SizedBox(height: 20),

          // Conditions
          Text('Conditions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Trigger when',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SegmentedButton<Logic>(
            segments: const [
              ButtonSegment(value: Logic.all, label: Text('ALL (AND)')),
              ButtonSegment(value: Logic.any, label: Text('ANY (OR)')),
            ],
            selected: {_logic},
            onSelectionChanged: (s) => setState(() => _logic = s.first),
          ),
          const SizedBox(height: 12),
          ..._rows.asMap().entries.map((e) => _ConditionCard(
                key: ValueKey(e.key),
                row: e.value,
                canRemove: _rows.length > 1,
                onRemove: () => setState(() => _rows.removeAt(e.key)),
                onChanged: () => setState(() {}),
              )),
          OutlinedButton.icon(
            onPressed: () => setState(() => _rows.add(_ConditionRow())),
            icon: const Icon(Icons.add),
            label: const Text('Add condition'),
          ),
          const SizedBox(height: 20),

          // Mode & cooldown
          Text('Behaviour', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<AlertMode>(
            segments: const [
              ButtonSegment(value: AlertMode.once, label: Text('One-time')),
              ButtonSegment(value: AlertMode.repeating, label: Text('Repeating')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          if (_mode == AlertMode.repeating) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Cooldown'),
                Expanded(
                  child: Slider(
                    value: _cooldownMinutes.toDouble(),
                    min: 0,
                    max: 240,
                    divisions: 24,
                    label: '${_cooldownMinutes}m',
                    onChanged: (v) =>
                        setState(() => _cooldownMinutes = v.round()),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    _cooldownMinutes == 0 ? 'None' : '${_cooldownMinutes} min',
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Expiry
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Expires'),
              subtitle: Text(_expiresAt == null
                  ? 'Never'
                  : DateFormat('d MMM yyyy, HH:mm').format(_expiresAt!)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _pickExpiry,
                  ),
                  if (_expiresAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _expiresAt = null),
                    ),
                ],
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _canSave && !_busy ? _save : null,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save alert'),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Condition row editing

class _ConditionRow {
  _ConditionRow({
    ConditionType? type,
    this.value,
    this.value2,
  })  : type = type ?? ConditionType.above,
        text = value?.toString() ?? '',
        text2 = value2?.toString() ?? '';

  factory _ConditionRow.fromCondition(Condition c) => _ConditionRow(
        type: c.type,
        value: c.value,
        value2: c.value2,
      );

  ConditionType type;
  double? value;
  double? value2;
  String text;
  String text2;

  bool get _isRange =>
      type == ConditionType.entersRange || type == ConditionType.leavesRange;

  bool get isValid {
    final a = double.tryParse(text);
    if (_isRange) {
      final b = double.tryParse(text2);
      return a != null && b != null && b > a;
    }
    return a != null;
  }

  Condition toCondition() => Condition(
        type: type,
        value: double.tryParse(text),
        value2: double.tryParse(text2),
      );

  void dispose() {
    // no controllers to release (plain TextFields with onChanged)
  }
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({
    super.key,
    required this.row,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final _ConditionRow row;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  static const _typeLabels = {
    ConditionType.above: 'Price above',
    ConditionType.below: 'Price below',
    ConditionType.crossesAbove: 'Crosses above',
    ConditionType.crossesBelow: 'Crosses below',
    ConditionType.bidAbove: 'Bid reaches',
    ConditionType.bidBelow: 'Bid falls to',
    ConditionType.askAbove: 'Ask reaches',
    ConditionType.askBelow: 'Ask falls to',
    ConditionType.changePercentAbove: 'Change ≥ %',
    ConditionType.entersRange: 'Enters range',
    ConditionType.leavesRange: 'Leaves range',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ConditionType>(
                    value: row.type,
                    decoration: const InputDecoration(
                        labelText: 'Condition', isDense: true),
                    items: _typeLabels.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (t) {
                      row.type = t ?? ConditionType.above;
                      onChanged();
                    },
                  ),
                ),
                if (canRemove)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.textSecondary),
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: false),
                    decoration: InputDecoration(
                      labelText: row._isRange ? 'From' : 'Value',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      row.text = v;
                      row.value = double.tryParse(v);
                      onChanged();
                    },
                  ),
                ),
                if (row._isRange) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'To', isDense: true),
                      onChanged: (v) {
                        row.text2 = v;
                        row.value2 = double.tryParse(v);
                        onChanged();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
