import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { setGlobalOptions } from "firebase-functions/v2";
import { MarketDataProvider } from "./provider";
import { TwelveDataProvider } from "./twelvedata";
import { evaluateAllAlerts } from "./evaluator";

admin.initializeApp();

setGlobalOptions({ region: "us-central1", maxInstances: 10 });

// ---------- Provider (swappable; OANDA later) ----------

function currentProvider(): MarketDataProvider {
  const key = process.env.TWELVEDATA_API_KEY;
  if (!key) {
    throw new HttpsError(
      "failed-precondition",
      "Market data provider is not configured (missing API key)."
    );
  }
  return new TwelveDataProvider(key);
}

// ---------- Callables used by the Flutter app ----------

/** Public instrument catalog, cached from the provider. */
export const getCatalog = onCall(async () => {
  const catalog = await currentProvider().supportedInstruments();
  return { instruments: catalog };
});

/** Batched quotes: one call covers N symbols (no per-alert requests). */
export const getQuotes = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const symbols = (request.data?.symbols as string[] | undefined)?.filter(
    (s): s is string => typeof s === "string" && s.length > 0
  );
  if (!symbols || symbols.length === 0) return { quotes: [] };
  if (symbols.length > 50) {
    throw new HttpsError("invalid-argument", "Too many symbols per call.");
  }
  const quotes = await currentProvider().getQuotes(symbols);
  return { quotes };
});

/** Chart candles for the instrument detail screen. */
export const getTimeSeries = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const symbol = String(request.data?.symbol ?? "");
  const interval = String(request.data?.interval ?? "1h");
  const outputsize = Math.min(Number(request.data?.outputsize ?? 96), 200);
  if (!symbol) throw new HttpsError("invalid-argument", "symbol required");

  const points = await currentProvider().getTimeSeries(symbol, {
    interval,
    outputsize,
  });
  return { points };
});

// ---------- Scheduled alert evaluation (filled in Step 5) ----------

/**
 * Polls the distinct watchlist of symbols that have enabled alerts and
 * evaluates every alert against the shared price data — one provider fetch
 * per symbol per run, regardless of how many alerts/users exist.
 */
export const evaluateAlerts = onSchedule(
  {
    schedule: "every 1 minutes",
    secrets: ["TWELVEDATA_API_KEY"],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async () => {
    await evaluateAllAlerts(currentProvider());
  }
);
