import { MarketDataProvider } from "./provider";
import { AssetClass, Instrument, PricePoint, Quote } from "./types";

const BASE = "https://api.twelvedata.com";

interface TDQuoteResponse {
  [key: string]: unknown;
}

function num(v: unknown): number | undefined {
  if (v === null || v === undefined) return undefined;
  const n = typeof v === "number" ? v : parseFloat(String(v));
  return Number.isFinite(n) ? n : undefined;
}

/** Curated default catalog — same list as the client-side fallback. */
const DEFAULT_INSTRUMENTS: Instrument[] = [
  { symbol: "EUR/USD", displayName: "Euro / US Dollar", assetClass: "forex" },
  { symbol: "GBP/USD", displayName: "British Pound / US Dollar", assetClass: "forex" },
  { symbol: "USD/JPY", displayName: "US Dollar / Japanese Yen", assetClass: "forex", pricePrecision: 3, pipSize: 0.01 },
  { symbol: "USD/CHF", displayName: "US Dollar / Swiss Franc", assetClass: "forex" },
  { symbol: "AUD/USD", displayName: "Australian Dollar / US Dollar", assetClass: "forex" },
  { symbol: "USD/CAD", displayName: "US Dollar / Canadian Dollar", assetClass: "forex" },
  { symbol: "NZD/USD", displayName: "New Zealand Dollar / US Dollar", assetClass: "forex" },
  { symbol: "EUR/GBP", displayName: "Euro / British Pound", assetClass: "forex" },
  { symbol: "XAU/USD", displayName: "Gold / US Dollar", assetClass: "metal", pricePrecision: 2, pipSize: 0.01 },
  { symbol: "XAG/USD", displayName: "Silver / US Dollar", assetClass: "metal", pricePrecision: 3, pipSize: 0.001 },
  { symbol: "SPX", displayName: "S&P 500", assetClass: "index", pricePrecision: 2, pipSize: 0.1 },
  { symbol: "IXIC", displayName: "Nasdaq Composite", assetClass: "index", pricePrecision: 2, pipSize: 0.1 },
  { symbol: "DJI", displayName: "Dow Jones 30", assetClass: "index", pricePrecision: 2, pipSize: 0.1 },
];

export class TwelveDataProvider implements MarketDataProvider {
  id = "twelvedata";

  constructor(private readonly apiKey: string) {}

  async supportedInstruments(): Promise<Instrument[]> {
    return DEFAULT_INSTRUMENTS;
  }

  async getQuotes(symbols: string[]): Promise<Quote[]> {
    if (symbols.length === 0) return [];

    const url =
      `${BASE}/quote?symbol=${encodeURIComponent(symbols.join(","))}` +
      `&apikey=${this.apiKey}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(15_000) });
    if (!res.ok) {
      throw new Error(`Twelve Data HTTP ${res.status}`);
    }
    const body = (await res.json()) as TDQuoteResponse;

    const code = body["code"];
    if (typeof code === "number" && code >= 400) {
      throw new Error(String(body["message"] ?? `API error ${code}`));
    }

    const quotes: Quote[] = [];
    for (const [key, value] of Object.entries(body)) {
      if (["code", "message", "status"].includes(key)) continue;
      if (typeof value !== "object" || value === null) continue;
      const v = value as Record<string, unknown>;
      const price = num(v["close"] ?? v["price"]);
      if (price === undefined) continue;
      quotes.push({
        symbol: (v["symbol"] as string) ?? key,
        price,
        bid: num(v["bid"]),
        ask: num(v["ask"]),
        prevClose: num(v["previous_close"]),
        timestamp: num(v["timestamp"]) !== undefined ? num(v["timestamp"])! * 1000 : undefined,
      });
    }
    return quotes;
  }

  async getTimeSeries(
    symbol: string,
    opts?: { interval?: string; outputsize?: number }
  ): Promise<PricePoint[]> {
    const interval = opts?.interval ?? "1h";
    const outputsize = Math.min(opts?.outputsize ?? 96, 200);
    const url =
      `${BASE}/time_series?symbol=${encodeURIComponent(symbol)}` +
      `&interval=${interval}&outputsize=${outputsize}&apikey=${this.apiKey}`;

    const res = await fetch(url, { signal: AbortSignal.timeout(15_000) });
    if (!res.ok) throw new Error(`Twelve Data HTTP ${res.status}`);
    const body = (await res.json()) as { values?: Record<string, string>[] };

    const points: PricePoint[] = [];
    for (const v of body.values ?? []) {
      const close = num(v["close"]);
      if (close === undefined) continue;
      points.push({
        time: new Date(v["datetime"] + "Z").getTime(),
        open: num(v["open"]),
        high: num(v["high"]),
        low: num(v["low"]),
        close,
      });
    }
    return points;
  }
}
