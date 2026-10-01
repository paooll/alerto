/// A snapshot of an instrument's price at a point in time.
class Quote {
  const Quote({
    required this.symbol,
    required this.price,
    this.bid,
    this.ask,
    this.prevClose,
    this.timestamp,
  });

  final String symbol;

  /// Last/mid price.
  final double price;
  final double? bid;
  final double? ask;
  final double? prevClose;

  /// When the provider produced this quote (UTC).
  final DateTime? timestamp;

  double? get spread => (bid != null && ask != null) ? ask! - bid! : null;

  /// Signed percent change vs previous close, if available.
  double? get changePercent {
    if (prevClose == null || prevClose == 0) return null;
    return (price - prevClose!) / prevClose! * 100;
  }
}

/// One point of a price series (candle close used for simple charts).
class PricePoint {
  const PricePoint({required this.time, required this.close, this.open, this.high, this.low});

  final DateTime time;
  final double close;
  final double? open;
  final double? high;
  final double? low;
}
