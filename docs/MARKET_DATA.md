# Market-Data Provider — Choice & Limitations

## Selected provider: Twelve Data (verified October 2026)

Verified against current published pricing/limits (sources: twelvedata.com/pricing, G2, marketplace listings):

| Plan | Cost | Rate limits | Forex | Gold (XAU/USD) | Indices/CFDs |
|---|---|---|---|---|---|
| **Free (Grow)** | $0 | **8 API credits/min, 800/day** | ✅ Real-time | ✅ | ⚠️ Partial — indices (SPX, IXIC, DJI) available; broker-style CFD symbols (e.g. `US30.cash`) generally **not** on free plan |
| Pro 610 | $29/mo | 610 credits/min, unlimited daily | ✅ | ✅ | ✅ |

### Why Twelve Data
- One clean REST API covers **forex, metals and indices** with the same quote/time-series endpoints — matches our single `MarketDataProvider` interface.
- **Batch quotes**: `/quote?symbol=A,B,C` returns many symbols in one response (1 credit per symbol) — ideal for our watchlist-based evaluator (1 fetch per distinct symbol per minute, not per alert).
- Generous free tier relative to Alpha Vantage (25 req/day — unusable for a 1-minute alert loop) and Finnhub (60 calls/min but forex free data is limited and CFD coverage weaker).
- Well-documented, plain JSON, no scraping required.

### Limitations (documented, not hidden)
1. **Free plan is 8 credits/min.** Our scheduled evaluator uses ~1 credit/min per distinct watched symbol. With ≤8 distinct symbols everything fits comfortably; beyond that you need the paid plan (or reduce evaluation frequency to every 2–5 minutes).
2. **True CFD symbols from brokers** (e.g. `US30.cash`, `DE40.cash`) are generally not on the free tier. We ship **index proxies** (SPX, IXIC, DJI) as CFD stand-ins and mark coverage clearly in the catalog.
3. **Forex quotes on the free tier may be delayed slightly** versus institutional feeds; fine for price alerts, not for trading decisions.
4. **Bid/ask**: Twelve Data returns bid/ask for FX where available; for indices the spread fields may be empty — the UI handles this gracefully and bid/ask alerts fall back to the last price.

## Swapping to OANDA later

Everything depends only on `MarketDataProvider`:

- **Flutter**: `lib/domain/market_data_provider.dart`
- **Cloud Functions**: `functions/src/provider.ts`

To switch providers:

1. Implement `MarketDataProvider` with OANDA's `/v3/accounts/{id}/pricing` (streaming or poll) and `/v3/instruments/{name}/candles`.
2. Register real bid/ask (OANDA gives both natively — better bid/ask alert support).
3. Change `currentProvider()` in `functions/src/index.ts`. No other code changes.

OANDA requires a funded/live account (or v20 practice account) — that's why it is not the default.
