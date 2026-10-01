import 'package:cloud_functions/cloud_functions.dart';

import '../domain/instrument.dart';
import '../domain/quote.dart';

/// Bridge from the app to callable Cloud Functions. The backend holds the
/// market-data API key and hides the provider from the client.
class BackendFunctions {
  static Future<Map<String, dynamic>> _call(String name,
      [Map<String, dynamic>? data]) async {
    final res = await FirebaseFunctions.instance
        .httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 20)))
        .call(data ?? {});
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<List<Instrument>> fetchCatalog() async {
    final data = await _call('getCatalog');
    return (data['instruments'] as List<dynamic>)
        .map((m) => Instrument.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Batched quotes: one callable invocation fetches many symbols.
  static Future<List<Quote>> fetchQuotes(List<String> symbols) async {
    final data = await _call('getQuotes', {'symbols': symbols});
    return (data['quotes'] as List<dynamic>)
        .map((m) => _quoteFromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  /// Chart candles for one symbol.
  static Future<List<PricePoint>> fetchTimeSeries(String symbol,
      {String interval = '1h', int outputsize = 96}) async {
    final data = await _call('getTimeSeries',
        {'symbol': symbol, 'interval': interval, 'outputsize': outputsize});
    return (data['points'] as List<dynamic>).map((p) {
      final m = Map<String, dynamic>.from(p as Map);
      return PricePoint(
        time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int, isUtc: true),
        close: (m['close'] as num).toDouble(),
        open: (m['open'] as num?)?.toDouble(),
        high: (m['high'] as num?)?.toDouble(),
        low: (m['low'] as num?)?.toDouble(),
      );
    }).toList();
  }

  static Quote _quoteFromMap(Map<String, dynamic> m) => Quote(
        symbol: m['symbol'] as String,
        price: (m['price'] as num).toDouble(),
        bid: (m['bid'] as num?)?.toDouble(),
        ask: (m['ask'] as num?)?.toDouble(),
        prevClose: (m['prevClose'] as num?)?.toDouble(),
        timestamp: m['timestamp'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int, isUtc: true),
      );
}
