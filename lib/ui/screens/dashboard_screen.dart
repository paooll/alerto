import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/instrument.dart';
import '../../providers/alert_providers.dart';
import '../../providers/market_providers.dart';
import '../../theme.dart';
import 'instrument_detail_screen.dart';
import 'instrument_search_screen.dart';

/// Dashboard: quick search entry + live watchlist of the default catalog.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final alerts = ref.watch(alertsProvider);

    final instruments = catalog.asData?.value ?? const <Instrument>[];
    final alertCounts = <String, int>{};
    alerts.asData?.value.where((a) => a.enabled && !a.isExpired).forEach((a) {
      alertCounts[a.symbol] = (alertCounts[a.symbol] ?? 0) + 1;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('PriceAlert'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New alert',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const InstrumentSearchScreen(),
            )),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search entry
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const InstrumentSearchScreen(),
              )),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.cardMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: AppTheme.textSecondary),
                    SizedBox(width: 10),
                    Text('Search Forex, Gold, CFDs…',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Markets',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Failed to load markets.\n\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
              data: (list) {
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(catalogProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (context, i) {
                      final inst = list[i];
                      return _MarketTile(
                        instrument: inst,
                        activeAlerts: alertCounts[inst.symbol] ?? 0,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Market tile with its own live quote subscription (per-symbol family
/// provider keeps subscriptions stable across rebuilds).
class _MarketTile extends ConsumerWidget {
  const _MarketTile({required this.instrument, required this.activeAlerts});

  final Instrument instrument;
  final int activeAlerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(quoteStreamProvider(instrument.symbol)).value;
    final prec = instrument.pricePrecision;
    final fmt = NumberFormat.decimalPattern()..minimumFractionDigits = prec;
    final change = quote?.changePercent;
    final up = (change ?? 0) >= 0;

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Text(instrument.symbol,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            if (activeAlerts > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$activeAlerts',
                    style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        subtitle: Text(instrument.displayName,
            style: const TextStyle(color: AppTheme.textSecondary)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(quote != null ? fmt.format(quote.price) : '…',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            if (change != null)
              Text(
                '${up ? '+' : ''}${change.toStringAsFixed(2)}%',
                style: TextStyle(
                    color: up ? AppTheme.green : AppTheme.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
          ],
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => InstrumentDetailScreen(instrument: instrument),
        )),
      ),
    );
  }
}
