import { Instrument, Quote, PricePoint } from "./types";

/**
 * Server-side market data source. Mirrors the Flutter domain interface so
 * the provider can be swapped (e.g. to OANDA) without touching alert
 * evaluation, Firestore code, or the client.
 */
export interface MarketDataProvider {
  id: string;
  supportedInstruments(): Promise<Instrument[]>;
  /** Batched: one call for N symbols. */
  getQuotes(symbols: string[]): Promise<Quote[]>;
  getTimeSeries(
    symbol: string,
    opts?: { interval?: string; outputsize?: number }
  ): Promise<PricePoint[]>;
}
