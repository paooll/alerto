import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/instrument.dart';
import '../../providers/market_providers.dart';
import '../../theme.dart';
import 'instrument_detail_screen.dart';

class InstrumentSearchScreen extends ConsumerStatefulWidget {
  const InstrumentSearchScreen({super.key});

  @override
  ConsumerState<InstrumentSearchScreen> createState() =>
      _InstrumentSearchScreenState();
}

class _InstrumentSearchScreenState
    extends ConsumerState<InstrumentSearchScreen> {
  String _query = '';

  static const _classLabels = {
    AssetClass.forex: 'Forex',
    AssetClass.metal: 'Metal',
    AssetClass.cfd: 'CFD',
    AssetClass.index: 'Index',
    AssetClass.crypto: 'Crypto',
    AssetClass.stock: 'Stock',
  };

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search instruments')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search symbol or name… (e.g. XAU, EUR)',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: catalog.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load instrument catalog.\n\n$e',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).textDim),
                  ),
                ),
              ),
              data: (instruments) {
                final q = _query.trim().toLowerCase();
                final results = q.isEmpty
                    ? instruments
                    : instruments
                        .where((i) =>
                            i.symbol.toLowerCase().contains(q) ||
                            i.displayName.toLowerCase().contains(q))
                        .toList();
                if (results.isEmpty) {
                  return const Center(
                    child: Text('No instruments match your search.'),
                  );
                }
                return ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (context, i) {
                    final inst = results[i];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        title: Text(inst.symbol,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(inst.displayName,
                            style: const TextStyle(
                                color: Theme.of(context).textDim)),
                        trailing: Chip(
                          label: Text(
                            _classLabels[inst.assetClass] ?? 'Other',
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                InstrumentDetailScreen(instrument: inst),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
