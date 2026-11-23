// Pure translation of a RevenueCat webhook event into the `entitlements` row
// it implies. Field names follow RevenueCat's "Event Types and Fields" docs.

export const ENTITLEMENT_ID = "premium";

export interface RcEvent {
  id?: string;
  type: string;
  event_timestamp_ms?: number;
  app_user_id?: string;
  original_app_user_id?: string;
  aliases?: string[];
  entitlement_ids?: string[] | null;
  /** Deprecated by RevenueCat in favour of `entitlement_ids`. */
  entitlement_id?: string | null;
  expiration_at_ms?: number | null;
  grace_period_expiration_at_ms?: number | null;
  environment?: "SANDBOX" | "PRODUCTION" | string;
  transferred_from?: string[];
  transferred_to?: string[];
}

export interface EntitlementChange {
  userId: string;
  isPremium: boolean;
  expiresAt: string | null;
}

const GRANTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "SUBSCRIPTION_EXTENDED",
  "NON_RENEWING_PURCHASE",
  "REFUND_REVERSED",
]);

// Access continues until the stored expiry; `is_premium()` enforces the date.
const KEEPS_UNTIL_EXPIRY = new Set(["CANCELLATION", "BILLING_ISSUE"]);

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID.test(value);
}

function iso(ms: number | null | undefined): string | null {
  return typeof ms === "number" ? new Date(ms).toISOString() : null;
}

function concernsPremium(event: RcEvent): boolean {
  const ids = event.entitlement_ids ??
    (event.entitlement_id ? [event.entitlement_id] : []);
  return ids.includes(ENTITLEMENT_ID);
}

function latestExpiry(event: RcEvent): string | null {
  const dates = [event.expiration_at_ms, event.grace_period_expiration_at_ms]
    .filter((ms): ms is number => typeof ms === "number");
  return dates.length ? iso(Math.max(...dates)) : null;
}

export function applyEvent(event: RcEvent): EntitlementChange | null {
  if (event.type === "TRANSFER") {
    const to = (event.transferred_to ?? []).find(isUuid);
    return to
      ? { userId: to, isPremium: true, expiresAt: iso(event.expiration_at_ms) }
      : null;
  }

  if (!isUuid(event.app_user_id) || !concernsPremium(event)) return null;
  const userId = event.app_user_id;

  if (GRANTS.has(event.type)) {
    return { userId, isPremium: true, expiresAt: iso(event.expiration_at_ms) };
  }
  if (KEEPS_UNTIL_EXPIRY.has(event.type)) {
    return { userId, isPremium: true, expiresAt: latestExpiry(event) };
  }
  if (event.type === "EXPIRATION") {
    return { userId, isPremium: false, expiresAt: iso(event.expiration_at_ms) };
  }
  return null;
}

export function transferredFrom(event: RcEvent): string[] {
  return event.type === "TRANSFER" ? (event.transferred_from ?? []).filter(isUuid) : [];
}

export function eventTime(event: RcEvent): string | null {
  return iso(event.event_timestamp_ms);
}

export function isAuthorized(
  header: string | null,
  secret: string | undefined,
): boolean {
  if (!secret || header === null) return false;
  const given = new TextEncoder().encode(header);
  const expected = new TextEncoder().encode(secret);
  let diff = given.length ^ expected.length;
  for (let i = 0; i < expected.length; i++) {
    diff |= (given[i] ?? 0) ^ expected[i];
  }
  return diff === 0;
}
