import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/alert.dart';
import '../../providers/alert_actions.dart';
import '../../providers/alert_providers.dart';
import '../../theme.dart';
import '../../providers/alert_describe.dart';

/// All alerts (active and paused) with quick enable/disable + delete.
class ActiveAlertsScreen extends ConsumerWidget {
  const ActiveAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);

    return alerts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load alerts.'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(alertsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyState();
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final alert = list[i];
            return _AlertTile(alert: alert);
          },
        );
      },
    );
  }
}

class _AlertTile extends ConsumerWidget {
  const _AlertTile({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upNext = alert.mode == AlertMode.once ? 'One-time' : 'Repeating';
    final statusColor = alert.isExpired
        ? Theme.of(context).textDim
        : alert.enabled
            ? AppColors.green
            : Theme.of(context).textDim;

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${alert.name ?? alert.displayName} · ${alert.symbol}',
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                alert.isExpired
                    ? 'Expired'
                    : alert.enabled
                        ? 'Active'
                        : 'Paused',
                style: TextStyle(color: statusColor, fontSize: 11),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(describeConditions(alert.conditions)),
            const SizedBox(height: 4),
            Text(
              '$upNext'
              '${alert.mode == AlertMode.repeating && alert.cooldownMinutes > 0 ? ' · ${alert.cooldownMinutes}m cooldown' : ''}'
              '${alert.expiresAt != null ? ' · expires ${DateFormat.MMMd().add_Hm().format(alert.expiresAt!.toLocal())}' : ''}',
              style: const TextStyle(
                  color: Theme.of(context).textDim, fontSize: 12),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: alert.enabled,
              onChanged: (v) => toggleAlert(ref, alert, v),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Theme.of(context).textDim),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete alert?'),
                    content: Text(
                        'Delete the alert on ${alert.symbol}? This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await deleteAlert(ref, alert);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Theme.of(context).textDim),
          const SizedBox(height: 12),
          const Text('No alerts yet'),
          const SizedBox(height: 4),
          const Text(
            'Search an instrument and create your first alert.',
            style: TextStyle(color: Theme.of(context).textDim),
          ),
        ],
      ),
    );
  }
}
