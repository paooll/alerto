import { getMessaging } from "firebase-admin/messaging";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { AlertDoc } from "./types";

const db = getFirestore();

/**
 * Sends the trigger push to every registered device of the user.
 * De-duplication is inherent: the evaluator writes lastTriggeredAt inside
 * the same run that calls this, so an alert cannot fire twice within its
 * cooldown, and one-time alerts are disabled after firing.
 */
export async function sendTriggerNotifications(
  userId: string,
  alert: AlertDoc,
  price: number
): Promise<void> {
  const devicesSnap = await db
    .collection("users")
    .doc(userId)
    .collection("devices")
    .get();

  if (devicesSnap.empty) return;

  const tokens = devicesSnap.docs.map((d) => d.data().token as string).filter(Boolean);
  if (tokens.length === 0) return;

  const symbol = alert.symbol;
  const title = alert.name ? `${alert.name}` : `Alerto · ${symbol}`;
  const body = `${symbol} ${alert.mode === "repeating" ? "triggered" : "hit your target"} at ${price}`;

  const message = {
    notification: { title, body },
    data: {
      type: "alertTriggered",
      symbol,
      price: String(price),
    },
    // Android: high priority so alerts arrive promptly even in Doze.
    android: { priority: "high" as const },
    // APNs: show the system banner in background/terminated state.
    apns: {
      payload: { aps: { sound: "default", badge: 1 } as { [key: string]: unknown } },
    },
    tokens,
  };

  const response = await getMessaging().sendEachForMulticast(message);

  // Clean up invalid/stale tokens so the device list stays healthy.
  const stale: string[] = [];
  response.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error?.code ?? "";
      if (
        code.includes("registration-token-not-registered") ||
        code.includes("invalid-registration-token") ||
        code.includes("invalid-argument")
      ) {
        stale.push(tokens[i]);
      }
    }
  });

  if (stale.length > 0) {
    await Promise.all(
      stale.map((token) =>
        db
          .collection("users")
          .doc(userId)
          .collection("devices")
          .doc(token)
          .delete()
          .catch(() => undefined)
      )
    );
  }

  await db
    .collection("marketState")
    .doc("fcmStats")
    .set(
      {
        lastSentAt: FieldValue.serverTimestamp(),
        sent: FieldValue.increment(response.successCount),
        failed: FieldValue.increment(response.failureCount),
      },
      { merge: true }
    )
    .catch(() => undefined);
}
