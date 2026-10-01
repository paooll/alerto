/// Instrument types supported by the app.
enum AssetClass { forex, metal, cfd, index, crypto, stock }

/// A tradeable instrument (e.g. EUR/USD, XAU/USD, US30.cash).
class Instrument {
  const Instrument({
    required this.symbol,
    required this.displayName,
    required this.assetClass,
    this.quoteCurrency = 'USD',
    this.pricePrecision = 5,
    this.pipSize = 0.0001,
  });

  /// Provider symbol, e.g. `XAU/USD`, `EUR/USD`, `US30`.
  final String symbol;
  final String displayName;
  final AssetClass assetClass;
  final String quoteCurrency;

  /// Digits used to display prices (5 for FX majors, 2 for gold/CFDs).
  final int pricePrecision;

  /// Size of one pip for this instrument.
  final double pipSize;

  Map<String, dynamic> toMap() => {
        'symbol': symbol,
        'displayName': displayName,
        'assetClass': assetClass.name,
        'quoteCurrency': quoteCurrency,
        'pricePrecision': pricePrecision,
        'pipSize': pipSize,
      };

  factory Instrument.fromMap(Map<String, dynamic> map) => Instrument(
        symbol: map['symbol'] as String,
        displayName: map['displayName'] as String? ?? map['symbol'] as String,
        assetClass:
            AssetClass.values.firstWhere((e) => e.name == map['assetClass'],
                orElse: () => AssetClass.forex),
        quoteCurrency: map['quoteCurrency'] as String? ?? 'USD',
        pricePrecision: (map['pricePrecision'] as num?)?.toInt() ?? 5,
        pipSize: (map['pipSize'] as num?)?.toDouble() ?? 0.0001,
      );
}
