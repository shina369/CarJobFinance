// Permanently deletes the signed-in user: cloud backup, profile and login.
//
// Deploy:  supabase functions deploy delete-account
// JWT verification stays on (the default), so only a signed-in user reaches
// this code; the service role key is injected by Supabase and never leaves it.
import { createClient } from "npm:@supabase/supabase-js@2";

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const authorization = req.headers.get("Authorization");
  if (!authorization) return reply(401, { error: "missing_token" });

  const url = Deno.env.get("SUPABASE_URL")!;

  // Who is asking: resolved from the caller's own token, never from the body.
  const asCaller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
  });
  const { data, error: userError } = await asCaller.auth.getUser();
  if (userError || !data.user) return reply(401, { error: "invalid_token" });
  const userId = data.user.id;

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Data first: if a step fails the login still exists and the user can retry.
  const backups = await admin.from("backups").delete().eq("user_id", userId);
  if (backups.error) return reply(500, { error: "backup_delete_failed" });

  const profile = await admin.from("profiles").delete().eq("id", userId);
  if (profile.error) return reply(500, { error: "profile_delete_failed" });

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) return reply(500, { error: "user_delete_failed" });

  return reply(200, { deleted: true });
});
