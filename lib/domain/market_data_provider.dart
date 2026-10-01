import 'instrument.dart';
import 'quote.dart';

/// Abstract market-data source. The whole app (and the backend) depends on
/// this interface only, so the provider can be swapped (e.g. to OANDA)
/// without touching UI, alert logic, or Firestore code.
abstract class MarketDataProvider {
  /// Human-readable provider id, e.g. "twelvedata".
  String get id;

  /// Instruments the provider supports for this app (forex, metals, CFDs).
  Future<List<Instrument>> supportedInstruments();

  /// Latest quote for a batch of symbols. Called with all symbols that have
  /// alerts/interest at once so one API call covers many alerts.
  Future<List<Quote>> getQuotes(List<String> symbols);

  /// Recent candles for the detail-screen chart.
  /// [interval] e.g. "5min", "1h", "1day"; [outputsize] number of points.
  Future<List<PricePoint>> getTimeSeries(
    String symbol, {
    String interval = '1h',
    int outputsize = 96,
  });
}
