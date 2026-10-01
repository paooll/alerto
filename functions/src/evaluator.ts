import { getFirestore } from "firebase-admin/firestore";
import { MarketDataProvider } from "./provider";

/**
 * Step 5 placeholder. The full implementation will:
 *  1. Collect distinct symbols across ALL users' enabled, unexpired alerts.
 *  2. Fetch one batch of quotes per distinct symbol (no per-alert requests).
 *  3. Evaluate conditions (AND/OR, crosses, ranges, % change, cooldown).
 *  4. Write alertHistory, update lastTriggeredAt / disable one-time alerts.
 *  5. Send FCM messages with de-duplication.
 */
export async function evaluateAllAlerts(provider: MarketDataProvider): Promise<void> {
  const db = getFirestore();
  const snap = await db.collection("marketState").doc("evaluator").get();
  void snap; // silence unused until Step 5
  void provider;
}
