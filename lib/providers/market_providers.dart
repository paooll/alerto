import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/instrument.dart';
import '../domain/quote.dart';
import 'backend_functions.dart';

/// Instrument catalog loaded from Cloud Functions (provider-agnostic).
final catalogProvider = FutureProvider<List<Instrument>>((ref) async {
  return BackendFunctions.fetchCatalog();
});

/// Live quote for a single symbol, refreshed periodically via Cloud
/// Functions so the client never touches the market-data API directly.
/// (Family keyed by string symbol — stable identity across rebuilds.)
final quoteStreamProvider =
    StreamProvider.family<Quote?, String>((ref, symbol) {
  final controller = StreamController<Quote?>();
  Timer? timer;

  Future<void> fetch() async {
    try {
      final quotes = await BackendFunctions.fetchQuotes([symbol]);
      controller.add(quotes.isEmpty ? null : quotes.first);
    } catch (e, st) {
      debugPrint('quote fetch failed for $symbol: $e\n$st');
    }
  }

  timer = Timer.periodic(const Duration(seconds: 15), (_) => fetch());
  fetch();

  ref.onDispose(() {
    timer?.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});
