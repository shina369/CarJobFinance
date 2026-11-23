// Mirrors RevenueCat's view of the `premium` entitlement into
// public.entitlements, which the backups RLS policies consult.
//
// Deploy:  supabase functions deploy revenuecat-webhook --no-verify-jwt
// Secret:  supabase secrets set REVENUECAT_WEBHOOK_SECRET=<value>
// RevenueCat sends no Supabase JWT, so the gateway check is off and the
// request is trusted only if its Authorization header equals the secret
// configured in the RevenueCat dashboard. Ignored events still get a 200 so
// RevenueCat stops retrying; database failures get a 500 so it retries.
import { createClient } from "npm:@supabase/supabase-js@2";
import {
  applyEvent,
  eventTime,
  isAuthorized,
  type RcEvent,
  transferredFrom,
} from "./handler.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function reply(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function readEvent(req: Request): Promise<RcEvent | null> {
  try {
    const event = (await req.json())?.event;
    return event && typeof event.type === "string" ? event : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!isAuthorized(req.headers.get("Authorization"), secret)) {
    return reply(401, { error: "unauthorized" });
  }

  const event = await readEvent(req);
  if (!event) return reply(400, { error: "invalid_event" });

  const ts = eventTime(event);
  const change = applyEvent(event);
  const from = transferredFrom(event);
  if (!ts || (!change && from.length === 0)) {
    return reply(200, { ignored: event.type });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  const { error } = event.type === "TRANSFER"
    ? await admin.rpc("transfer_entitlement", {
      from_ids: from,
      to_id: change?.userId ?? null,
      expires: change?.expiresAt ?? null,
      ts,
    })
    : await admin.rpc("apply_entitlement", {
      uid: change!.userId,
      premium: change!.isPremium,
      expires: change!.expiresAt,
      ts,
    });
  if (error) {
    console.error("entitlement write failed", event.id, error.message);
    return reply(500, { error: "entitlement_write_failed" });
  }

  return reply(200, { applied: event.type });
});
