import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/instrument.dart';
import '../domain/market_data_provider.dart';
import '../domain/quote.dart';

/// Twelve Data implementation of [MarketDataProvider].
///
/// Free plan: 8 API credits/minute, 800/day. Each `quote` batch call costs
/// 1 credit per symbol, so the backend polls a *watchlist* of symbols (the
/// distinct set across all alerts), not one call per alert.
///
/// The API key is NEVER embedded in the app — this class is used on the
/// backend (Cloud Functions) where the key lives in server config/env.
class TwelveDataProvider implements MarketDataProvider {
  TwelveDataProvider({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _base = 'https://api.twelvedata.com';

  @override
  String get id => 'twelvedata';

  /// Curated default catalog. Forex & gold are on the free plan; many CFD /
  /// index symbols are available too — verify per symbol in the dashboard.
  static const List<Instrument> defaultInstruments = [
    // FX majors (free plan)
    Instrument(symbol: 'EUR/USD', displayName: 'Euro / US Dollar', assetClass: AssetClass.forex),
    Instrument(symbol: 'GBP/USD', displayName: 'British Pound / US Dollar', assetClass: AssetClass.forex),
    Instrument(symbol: 'USD/JPY', displayName: 'US Dollar / Japanese Yen', assetClass: AssetClass.forex, pricePrecision: 3, pipSize: 0.01),
    Instrument(symbol: 'USD/CHF', displayName: 'US Dollar / Swiss Franc', assetClass: AssetClass.forex),
    Instrument(symbol: 'AUD/USD', displayName: 'Australian Dollar / US Dollar', assetClass: AssetClass.forex),
    Instrument(symbol: 'USD/CAD', displayName: 'US Dollar / Canadian Dollar', assetClass: AssetClass.forex),
    Instrument(symbol: 'NZD/USD', displayName: 'New Zealand Dollar / US Dollar', assetClass: AssetClass.forex),
    Instrument(symbol: 'EUR/GBP', displayName: 'Euro / British Pound', assetClass: AssetClass.forex),
    // Metals
    Instrument(symbol: 'XAU/USD', displayName: 'Gold / US Dollar', assetClass: AssetClass.metal, pricePrecision: 2, pipSize: 0.01),
    Instrument(symbol: 'XAG/USD', displayName: 'Silver / US Dollar', assetClass: AssetClass.metal, pricePrecision: 3, pipSize: 0.001),
    // Indices / CFD-style symbols (verify availability on your plan)
    Instrument(symbol: 'SPX', displayName: 'S&P 500', assetClass: AssetClass.index, pricePrecision: 2, pipSize: 0.1),
    Instrument(symbol: 'IXIC', displayName: 'Nasdaq Composite', assetClass: AssetClass.index, pricePrecision: 2, pipSize: 0.1),
    Instrument(symbol: 'DJI', displayName: 'Dow Jones 30', assetClass: AssetClass.index, pricePrecision: 2, pipSize: 0.1),
  ];

  @override
  Future<List<Instrument>> supportedInstruments() async => defaultInstruments;

  @override
  Future<List<Quote>> getQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return [];
    final uri = Uri.parse('$_base/quote').replace(queryParameters: {
      'symbol': symbols.join(','),
      'apikey': apiKey,
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw MarketDataException('Twelve Data HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final code = body['code'];
    if (code is int && code >= 400) {
      throw MarketDataException(body['message'] as String? ?? 'API error $code');
    }

    final quotes = <Quote>[];
    body.forEach((key, value) {
      if (key == 'code' || key == 'message' || key == 'status') return;
      if (value is! Map<String, dynamic>) return;
      final symbol = value['symbol'] as String? ?? key;
      final price = double.tryParse('${value['close'] ?? value['price'] ?? ''}');
      if (price == null) return;
      quotes.add(Quote(
        symbol: symbol,
        price: price,
        bid: double.tryParse('${value['bid'] ?? ''}'),
        ask: double.tryParse('${value['ask'] ?? ''}'),
        prevClose: double.tryParse('${value['previous_close'] ?? ''}'),
        timestamp: value['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (value['timestamp'] as num).toInt() * 1000, isUtc: true)
            : null,
      ));
    });
    return quotes;
  }

  @override
  Future<List<PricePoint>> getTimeSeries(
    String symbol, {
    String interval = '1h',
    int outputsize = 96,
  }) async {
    final uri = Uri.parse('$_base/time_series').replace(queryParameters: {
      'symbol': symbol,
      'interval': interval,
      'outputsize': '$outputsize',
      'apikey': apiKey,
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw MarketDataException('Twelve Data HTTP ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final values = body['values'] as List<dynamic>? ?? [];
    return values
        .map((v) {
          final m = v as Map<String, dynamic>;
          final close = double.tryParse('${m['close']}');
          if (close == null) return null;
          return PricePoint(
            time: DateTime.parse('${m['datetime']}').toUtc(),
            close: close,
            open: double.tryParse('${m['open']}'),
            high: double.tryParse('${m['high']}'),
            low: double.tryParse('${m['low']}'),
          );
        })
        .whereType<PricePoint>()
        .toList();
  }
}

class MarketDataException implements Exception {
  MarketDataException(this.message);
  final String message;
  @override
  String toString() => 'MarketDataException: $message';
}
