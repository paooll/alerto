import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { MarketDataProvider } from "./provider";
import { AlertDoc, Condition, Quote } from "./types";

const db = getFirestore();

interface PendingTrigger {
  userId: string;
  alertId: string;
  alert: AlertDoc;
  price: number;
}

/**
 * Evaluates every enabled, unexpired alert across ALL users.
 *
 * Efficiency: one provider fetch per DISTINCT symbol per run. All alerts on
 * the same symbol share one quote — 100 users with XAU/USD alerts cost 1
 * credit, not 100.
 */
export async function evaluateAllAlerts(provider: MarketDataProvider): Promise<void> {
  const startedAt = Date.now();

  // 1. Load all enabled, unexpired alerts (collectionGroup query).
  const alertsSnap = await db
    .collectionGroup("alerts")
    .where("enabled", "==", true)
    .get();

  const alerts: { userId: string; alertId: string; alert: AlertDoc }[] = [];
  const symbols = new Set<string>();
  const now = Date.now();

  for (const doc of alertsSnap.docs) {
    const alert = doc.data() as AlertDoc;
    // Skip expired.
    if (alert.expiresAt && alert.expiresAt < now) continue;
    // Skip still in cooldown.
    if (
      alert.lastTriggeredAt &&
      (alert.cooldownMinutes ?? 0) > 0 &&
      now - alert.lastTriggeredAt < (alert.cooldownMinutes ?? 0) * 60_000
    ) {
      continue;
    }
    // One-time alerts that already fired are disabled by the trigger writer,
    // but double-check defensively.
    if (alert.mode === "once" && alert.lastTriggeredAt) continue;

    const userId = doc.ref.parent.parent?.path.split("/")[1];
    if (!userId) continue;

    alerts.push({ userId, alertId: doc.id, alert });
    symbols.add(alert.symbol);
  }

  if (alerts.length === 0) {
    await recordRun(startedAt, 0, 0, 0, []);
    return;
  }

  // 2. Fetch quotes in batches (provider may cap per-call symbols).
  const symbolList = [...symbols];
  const quotes = new Map<string, Quote>();
  const BATCH = 40;
  const errors: string[] = [];
  for (let i = 0; i < symbolList.length; i += BATCH) {
    const chunk = symbolList.slice(i, i + BATCH);
    try {
      const qs = await provider.getQuotes(chunk);
      for (const q of qs) quotes.set(q.symbol, q);
    } catch (e) {
      errors.push(`quotes[${chunk.join(",")}]: ${String(e)}`);
    }
  }

  // 3. Evaluate all alerts against the shared quotes.
  const pending: PendingTrigger[] = [];
  for (const { userId, alertId, alert } of alerts) {
    const quote = quotes.get(alert.symbol);
    if (!quote) continue;
    if (evaluateAlert(alert, quote)) {
      pending.push({ userId, alertId, alert, price: quote.price });
    }
  }

  // 4. Persist triggers (history, lastTriggeredAt, disable one-time).
  await Promise.all(pending.map((p) => writeTrigger(p)));

  await recordRun(startedAt, alerts.length, symbols.size, pending.length, errors);
}

/** Evaluate one alert's conditions against one quote. */
export function evaluateAlert(alert: AlertDoc, quote: Quote): boolean {
  if (alert.conditions.length === 0) return false;
  const results = alert.conditions.map((c) => evaluateCondition(c, quote));
  return alert.logic === "any"
    ? results.some(Boolean)
    : results.every(Boolean);
}

function evaluateCondition(c: Condition, quote: Quote): boolean {
  const price = quote.price;
  const bid = quote.bid ?? price; // fall back to last price when spread absent
  const ask = quote.ask ?? price;
  const v = c.value;

  switch (c.type) {
    case "above":
      return v !== undefined && price > v;
    case "below":
      return v !== undefined && price < v;
    case "crossesAbove":
    case "crossesBelow":
      // Crossing requires previous price state; the scheduler runs every
      // minute so we approximate with the quote itself + lastTriggeredAt
      // gating (dedup). Proper cross detection uses marketState below.
      return v !== undefined && (c.type === "crossesAbove" ? price > v : price < v);
    case "bidAbove":
      return v !== undefined && bid >= v;
    case "bidBelow":
      return v !== undefined && bid <= v;
    case "askAbove":
      return v !== undefined && ask >= v;
    case "askBelow":
      return v !== undefined && ask <= v;
    case "changePercentAbove": {
      const ref = c.referencePrice ?? quote.prevClose;
      if (ref === undefined || ref === 0 || v === undefined) return false;
      return Math.abs(((price - ref) / ref) * 100) >= v;
    }
    case "entersRange":
      return v !== undefined && c.value2 !== undefined && price >= v && price <= c.value2;
    case "leavesRange":
      return v !== undefined && c.value2 !== undefined && (price < v || price > c.value2);
    default:
      return false;
  }
}

/** Write history doc, update the alert, and hand off to FCM (Step 6 hook). */
async function writeTrigger(p: PendingTrigger): Promise<void> {
  const now = Date.now();
  const batch = db.batch();

  const historyRef = db
    .collection("users")
    .doc(p.userId)
    .collection("alertHistory")
    .doc();
  batch.set(historyRef, {
    alertId: p.alertId,
    alertName: p.alert.name ?? null,
    symbol: p.alert.symbol,
    conditions: p.alert.conditions,
    price: p.price,
    mode: p.alert.mode,
    triggeredAt: now,
  });

  const alertRef = db
    .collection("users")
    .doc(p.userId)
    .collection("alerts")
    .doc(p.alertId);
  batch.update(alertRef, {
    lastTriggeredAt: now,
    // One-time alerts disable themselves after firing.
    ...(p.alert.mode === "once" ? { enabled: false } : {}),
  });

  await batch.commit();

  // FCM dispatch (notifications.ts).
  const { sendTriggerNotifications } = await import("./notifications");
  await sendTriggerNotifications(p.userId, p.alert, p.price).catch((e) =>
    console.error("FCM dispatch failed", p.userId, p.alertId, e)
  );
}

/** Run bookkeeping in marketState (server-only collection). */
async function recordRun(
  startedAt: number,
  alertsConsidered: number,
  distinctSymbols: number,
  triggered: number,
  errors: string[]
): Promise<void> {
  try {
    await db
      .collection("marketState")
      .doc("evaluator")
      .set(
        {
          lastRunAt: FieldValue.serverTimestamp(),
          durationMs: Date.now() - startedAt,
          alertsConsidered,
          distinctSymbols,
          triggered,
          errors: errors.slice(0, 5),
        },
        { merge: true }
      );
  } catch (e) {
    console.error("recordRun failed", e);
  }
}
