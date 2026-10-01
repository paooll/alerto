import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/instrument.dart';
import '../../domain/quote.dart';
import '../../providers/alert_providers.dart';
import '../../providers/market_providers.dart';
import '../../providers/alert_describe.dart';
import '../../theme.dart';
import '../widgets/price_chart.dart';
import 'alert_edit_screen.dart';

class InstrumentDetailScreen extends ConsumerWidget {
  const InstrumentDetailScreen({super.key, required this.instrument});

  final Instrument instrument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(quoteStreamProvider(instrument.symbol));
    final quote = quotes.asData?.value;
    final alerts = ref.watch(alertsBySymbolProvider(instrument.symbol));

    return Scaffold(
      appBar: AppBar(title: Text(instrument.symbol)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _PriceHeader(instrument: instrument, quote: quote),
          _StatsGrid(quote: quote),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Price chart',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          PriceChart(instrument: instrument),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Active alerts',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          alerts.when(
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )),
            error: (e, _) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Could not load alerts.'),
            ),
            data: (list) {
              final active =
                  list.where((a) => a.enabled && !a.isExpired).toList();
              if (active.isEmpty) {
                return const _EmptyAlerts();
              }
              return Column(
                children: active
                    .map((a) => Card(
                          child: ListTile(
                            title: Text(a.name ?? a.displayName),
                            subtitle: Text(describeConditions(a.conditions)),
                            trailing: const Icon(Icons.notifications_active,
                                color: AppTheme.gold),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.bg,
        icon: const Icon(Icons.add_alert),
        label: const Text('Create alert'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AlertEditScreen(instrument: instrument),
        )),
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.notifications_off_outlined,
                color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No active alerts for this instrument yet.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceHeader extends StatelessWidget {
  const _PriceHeader({required this.instrument, this.quote});

  final Instrument instrument;
  final Quote? quote;

  @override
  Widget build(BuildContext context) {
    final change = quote?.changePercent;
    final up = (change ?? 0) >= 0;
    final prec = instrument.pricePrecision;
    final fmt = NumberFormat.decimalPattern()..minimumFractionDigits = prec;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(instrument.displayName,
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                quote != null ? fmt.format(quote!.price) : '—',
                style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800) ??
                    const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
              ),
              if (quote?.timestamp != null) ...[
                const SizedBox(width: 10),
                Text(
                  DateFormat('HH:mm:ss').format(quote!.timestamp!.toLocal()),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ],
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: up ? AppTheme.green : AppTheme.red, size: 28),
              Text(
                '${up ? '+' : ''}${change.toStringAsFixed(2)}% vs prev close',
                style: TextStyle(
                    color: up ? AppTheme.green : AppTheme.red,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({this.quote});

  final Quote? quote;

  @override
  Widget build(BuildContext context) {
    final spread = quote?.spread;
    final cells = [
      ('Bid', quote?.bid),
      ('Ask', quote?.ask),
      ('Spread', spread),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: cells
            .map((c) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        Text(c.$1,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          c.$2 != null
                              ? NumberFormat.decimalPattern()
                                  .format(c.$2)
                              : '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
