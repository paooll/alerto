import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/alert_history_entry.dart';
import '../../providers/alert_describe.dart';
import '../../theme.dart';

/// Groups history entries by calendar day (local time) with sticky headers.
class GroupedHistoryList extends StatelessWidget {
  const GroupedHistoryList({super.key, required this.entries});

  final List<AlertHistoryEntry> entries;

  String _dayLabel(DateTime local) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE, d MMM yyyy').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AlertHistoryEntry>>{};
    for (final e in entries) {
      final label = _dayLabel(e.triggeredAt.toLocal());
      groups.putIfAbsent(label, () => []).add(e);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final label = groups.keys.elementAt(i);
        final items = groups[label]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            ...items.map((e) => _HistoryTile(entry: e)),
          ],
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final AlertHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.Hm().format(entry.triggeredAt.toLocal());
    final title = entry.alertName ?? entry.symbol;
    final subtitle = entry.conditions.isEmpty
        ? entry.symbol
        : describeConditions(entry.conditions);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.gold.withOpacity(0.13),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.notifications_active,
              color: AppTheme.gold, size: 19),
        ),
        title: Text(
          '$title · ${entry.symbol}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              entry.price.toStringAsFixed(
                  entry.price.truncateToDouble() == entry.price ? 2 : 5),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(time,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
