import { assertEquals } from "jsr:@std/assert@1";
import {
  applyEvent,
  eventTime,
  isAuthorized,
  type RcEvent,
  transferredFrom,
} from "./handler.ts";

const USER = "6f1c2b0e-3d4a-4f5b-9c8d-7e6f5a4b3c2d";
const OTHER = "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d";
const EXPIRES_MS = Date.UTC(2027, 10, 23, 12, 0, 0);
const EXPIRES_ISO = "2027-11-23T12:00:00.000Z";
const EVENT_MS = Date.UTC(2026, 10, 23, 12, 0, 0);

function event(overrides: Partial<RcEvent>): RcEvent {
  return {
    id: "evt-1",
    type: "INITIAL_PURCHASE",
    app_user_id: USER,
    original_app_user_id: USER,
    aliases: [USER],
    entitlement_ids: ["premium"],
    expiration_at_ms: EXPIRES_MS,
    event_timestamp_ms: EVENT_MS,
    environment: "PRODUCTION",
    ...overrides,
  };
}

for (const type of ["INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "UNCANCELLATION"]) {
  Deno.test(`${type} grants premium until expiration_at_ms`, () => {
    assertEquals(applyEvent(event({ type })), {
      userId: USER,
      isPremium: true,
      expiresAt: EXPIRES_ISO,
    });
  });
}

Deno.test("CANCELLATION keeps premium until the expiration date", () => {
  assertEquals(applyEvent(event({ type: "CANCELLATION" })), {
    userId: USER,
    isPremium: true,
    expiresAt: EXPIRES_ISO,
  });
});

Deno.test("BILLING_ISSUE keeps premium until the expiration date", () => {
  assertEquals(applyEvent(event({ type: "BILLING_ISSUE" })), {
    userId: USER,
    isPremium: true,
    expiresAt: EXPIRES_ISO,
  });
});

Deno.test("BILLING_ISSUE keeps premium through the grace period", () => {
  const grace = Date.UTC(2027, 11, 7, 12, 0, 0);
  assertEquals(
    applyEvent(event({ type: "BILLING_ISSUE", grace_period_expiration_at_ms: grace })),
    { userId: USER, isPremium: true, expiresAt: "2027-12-07T12:00:00.000Z" },
  );
});

Deno.test("EXPIRATION revokes premium", () => {
  assertEquals(applyEvent(event({ type: "EXPIRATION", expiration_at_ms: EVENT_MS })), {
    userId: USER,
    isPremium: false,
    expiresAt: "2026-11-23T12:00:00.000Z",
  });
});

Deno.test("EXPIRATION revokes premium even with a later expiry", () => {
  assertEquals(applyEvent(event({ type: "EXPIRATION" }))?.isPremium, false);
});

Deno.test("TRANSFER grants premium to transferred_to", () => {
  const transfer: RcEvent = {
    id: "evt-2",
    type: "TRANSFER",
    event_timestamp_ms: EVENT_MS,
    transferred_from: [OTHER],
    transferred_to: [USER],
  };
  assertEquals(applyEvent(transfer), { userId: USER, isPremium: true, expiresAt: null });
});

Deno.test("TRANSFER revokes premium from transferred_from", () => {
  const transfer: RcEvent = {
    id: "evt-2",
    type: "TRANSFER",
    event_timestamp_ms: EVENT_MS,
    transferred_from: [OTHER, "$RCAnonymousID:abc"],
    transferred_to: [USER],
  };
  assertEquals(transferredFrom(transfer), [OTHER]);
});

Deno.test("TRANSFER to a non-UUID id is ignored", () => {
  const transfer: RcEvent = {
    id: "evt-2",
    type: "TRANSFER",
    event_timestamp_ms: EVENT_MS,
    transferred_from: [OTHER],
    transferred_to: ["$RCAnonymousID:abc"],
  };
  assertEquals(applyEvent(transfer), null);
});

Deno.test("transferredFrom is empty for other events", () => {
  assertEquals(transferredFrom(event({})), []);
});

Deno.test("anonymous app_user_id is ignored", () => {
  assertEquals(applyEvent(event({ app_user_id: "$RCAnonymousID:8f2e" })), null);
});

Deno.test("unknown event type is ignored", () => {
  assertEquals(applyEvent(event({ type: "SOMETHING_NEW" })), null);
});

for (
  const type of [
    "TEST",
    "SUBSCRIPTION_PAUSED",
    "TEMPORARY_ENTITLEMENT_GRANT",
    "NON_RENEWING_PURCHASE",
  ]
) {
  Deno.test(`${type} is ignored`, () => {
    assertEquals(applyEvent(event({ type })), null);
  });
}

Deno.test("events for another entitlement are ignored", () => {
  assertEquals(applyEvent(event({ entitlement_ids: ["pro"] })), null);
});

Deno.test("events without entitlement ids are ignored", () => {
  assertEquals(applyEvent(event({ entitlement_ids: null })), null);
});

Deno.test("deprecated entitlement_id is still honoured", () => {
  assertEquals(
    applyEvent(event({ entitlement_ids: undefined, entitlement_id: "premium" }))?.isPremium,
    true,
  );
});

Deno.test("production events are applied", () => {
  assertEquals(applyEvent(event({ environment: "PRODUCTION" }))?.isPremium, true);
});

Deno.test("sandbox events are ignored by default", () => {
  assertEquals(applyEvent(event({ environment: "SANDBOX" })), null);
});

Deno.test("events without environment are ignored by default", () => {
  assertEquals(applyEvent(event({ environment: undefined })), null);
});

Deno.test("sandbox events are applied when sandbox is allowed", () => {
  assertEquals(applyEvent(event({ environment: "SANDBOX" }), { allowSandbox: true }), {
    userId: USER,
    isPremium: true,
    expiresAt: EXPIRES_ISO,
  });
});

Deno.test("sandbox TRANSFER is ignored by default", () => {
  const transfer: RcEvent = {
    type: "TRANSFER",
    event_timestamp_ms: EVENT_MS,
    environment: "SANDBOX",
    transferred_from: [OTHER],
    transferred_to: [USER],
  };
  assertEquals(applyEvent(transfer), null);
  assertEquals(transferredFrom(transfer), []);
  assertEquals(transferredFrom(transfer, { allowSandbox: true }), [OTHER]);
});

Deno.test("TRANSFER never carries an expiry from the event", () => {
  const transfer: RcEvent = {
    type: "TRANSFER",
    event_timestamp_ms: EVENT_MS,
    expiration_at_ms: EXPIRES_MS,
    transferred_from: [OTHER],
    transferred_to: [USER],
  };
  assertEquals(applyEvent(transfer)?.expiresAt, null);
});

Deno.test("out-of-range or non-numeric expiry becomes null instead of throwing", () => {
  assertEquals(applyEvent(event({ expiration_at_ms: 1e20 }))?.expiresAt, null);
  assertEquals(applyEvent(event({ expiration_at_ms: NaN }))?.expiresAt, null);
  assertEquals(
    applyEvent(event({ expiration_at_ms: "soon" as unknown as number }))?.expiresAt,
    null,
  );
  assertEquals(
    applyEvent(event({ type: "BILLING_ISSUE", grace_period_expiration_at_ms: 1e20 }))
      ?.expiresAt,
    EXPIRES_ISO,
  );
});

Deno.test("out-of-range event timestamp becomes null instead of throwing", () => {
  assertEquals(eventTime(event({ event_timestamp_ms: 1e20 })), null);
});

Deno.test("string entitlement_ids do not substring-match", () => {
  assertEquals(
    applyEvent(event({ entitlement_ids: "premium_plus" as unknown as string[] })),
    null,
  );
});

Deno.test("non-array transfer lists are ignored", () => {
  const transfer = {
    type: "TRANSFER",
    event_timestamp_ms: EVENT_MS,
    transferred_from: OTHER,
    transferred_to: USER,
  } as unknown as RcEvent;
  assertEquals(applyEvent(transfer), null);
  assertEquals(transferredFrom(transfer), []);
});

Deno.test("purchase without expiration has no expiry", () => {
  assertEquals(applyEvent(event({ expiration_at_ms: null }))?.expiresAt, null);
});

Deno.test("eventTime turns event_timestamp_ms into the ordering timestamp", () => {
  assertEquals(eventTime(event({})), "2026-11-23T12:00:00.000Z");
});

Deno.test("an older event carries an older ordering timestamp", () => {
  const older = eventTime(event({ event_timestamp_ms: EVENT_MS - 1000 }));
  const newer = eventTime(event({}));
  assertEquals(older! < newer!, true);
});

Deno.test("eventTime is null without event_timestamp_ms", () => {
  assertEquals(eventTime({ type: "RENEWAL" } as RcEvent), null);
});

Deno.test("isAuthorized accepts only the configured secret", () => {
  assertEquals(isAuthorized("s3cret-value", "s3cret-value"), true);
  assertEquals(isAuthorized("s3cret-valuX", "s3cret-value"), false);
  assertEquals(isAuthorized("s3cret", "s3cret-value"), false);
  assertEquals(isAuthorized(null, "s3cret-value"), false);
});

Deno.test("isAuthorized rejects everything when the secret is unset", () => {
  assertEquals(isAuthorized("", undefined), false);
  assertEquals(isAuthorized("anything", undefined), false);
  assertEquals(isAuthorized("", ""), false);
});
