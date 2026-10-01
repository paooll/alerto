export type AssetClass = "forex" | "metal" | "cfd" | "index" | "crypto" | "stock";

export interface Instrument {
  symbol: string;
  displayName: string;
  assetClass: AssetClass;
  quoteCurrency?: string;
  pricePrecision?: number;
  pipSize?: number;
}

export interface Quote {
  symbol: string;
  price: number;
  bid?: number;
  ask?: number;
  prevClose?: number;
  timestamp?: number; // epoch ms (UTC)
}

export interface PricePoint {
  time: number; // epoch ms
  open?: number;
  high?: number;
  low?: number;
  close: number;
}

export type ConditionType =
  | "above"
  | "below"
  | "crossesAbove"
  | "crossesBelow"
  | "bidAbove"
  | "bidBelow"
  | "askAbove"
  | "askBelow"
  | "changePercentAbove"
  | "entersRange"
  | "leavesRange";

export interface Condition {
  type: ConditionType;
  value?: number;
  value2?: number;
  referencePrice?: number;
}

export interface AlertDoc {
  symbol: string;
  name?: string | null;
  displayName?: string;
  conditions: Condition[];
  logic: "all" | "any";
  mode: "once" | "repeating";
  cooldownMinutes?: number;
  enabled: boolean;
  createdAt: number;
  expiresAt?: number;
  lastTriggeredAt?: number;
}

export interface TriggeredAlert {
  userId: string;
  alertId: string;
  alert: AlertDoc;
  price: number;
}
