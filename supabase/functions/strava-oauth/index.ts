import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  decryptToken,
  encryptToken,
  importEncryptionKey,
} from "../_shared/token-crypto.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const STRAVA_CLIENT_ID = Deno.env.get("STRAVA_CLIENT_ID") ?? "";
const STRAVA_CLIENT_SECRET = Deno.env.get("STRAVA_CLIENT_SECRET") ?? "";
const ENCRYPTION_KEY_B64 = Deno.env.get("INTEGRATION_ENCRYPTION_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-clerk-token",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Decode (not verify) the Clerk JWT to extract clerk_id — same pattern as
// coach-respond. The Supabase gateway validates the anon key on the
// Authorization header; this header carries identity only.
function decodeClerkId(clerkToken: string): string | null {
  try {
    const parts = clerkToken.split(".");
    if (parts.length !== 3) throw new Error("bad structure");
    const payload = JSON.parse(
      atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"))
    );
    if (!payload.sub) throw new Error("no sub");
    return payload.sub as string;
  } catch {
    return null;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
  }

  const action = new URL(req.url).searchParams.get("action");
  if (action !== "exchange" && action !== "refresh") {
    return new Response(
      JSON.stringify({ error: "action must be 'exchange' or 'refresh'" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const clerkToken = req.headers.get("x-clerk-token");
  if (!clerkToken) {
    return new Response(
      JSON.stringify({ error: "Missing x-clerk-token" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const clerkId = decodeClerkId(clerkToken);
  if (!clerkId) {
    return new Response(
      JSON.stringify({ error: "Invalid token" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // Service-role client — Clerk is not Supabase Auth, so RLS is bypassed here
  // and the resolved user_id (from our own users table) is the only trust
  // boundary; it is never taken from the request body.
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  const { data: userRow, error: userError } = await supabase
    .from("users")
    .select("id")
    .eq("clerk_id", clerkId)
    .maybeSingle();

  if (userError || !userRow) {
    return new Response(
      JSON.stringify({ error: "User not found" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const userId = (userRow as { id: string }).id;
  const encKey = await importEncryptionKey(ENCRYPTION_KEY_B64);

  // ── action=exchange: convert Strava auth code → tokens ─────────────────
  if (action === "exchange") {
    let code: string;
    try {
      const body = await req.json();
      if (!body.code) throw new Error();
      code = body.code;
    } catch {
      return new Response(
        JSON.stringify({ error: "body must include { code: string }" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const stravaRes = await fetch("https://www.strava.com/oauth/token", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        client_id: STRAVA_CLIENT_ID,
        client_secret: STRAVA_CLIENT_SECRET,
        code,
        grant_type: "authorization_code",
      }),
    });

    if (!stravaRes.ok) {
      return new Response(
        JSON.stringify({ error: "Strava rejected the auth code" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const strava = await stravaRes.json();

    const encryptedAccess = await encryptToken(strava.access_token, encKey);
    const encryptedRefresh = await encryptToken(strava.refresh_token, encKey);

    const { error: upsertError } = await supabase.from("integrations").upsert(
      {
        user_id: userId,
        provider: "strava",
        provider_user_id: String(strava.athlete.id),
        access_token: encryptedAccess,
        refresh_token: encryptedRefresh,
        token_expires_at: new Date(
          (strava.expires_at as number) * 1000
        ).toISOString(),
        is_active: true,
      },
      { onConflict: "user_id,provider" }
    );

    if (upsertError) {
      return new Response(
        JSON.stringify({ error: "Failed to store integration" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── action=refresh: rotate an expired access token ──────────────────────
  const { data: integration, error: fetchError } = await supabase
    .from("integrations")
    .select("refresh_token")
    .eq("user_id", userId)
    .eq("provider", "strava")
    .eq("is_active", true)
    .single();

  if (fetchError || !integration) {
    return new Response(
      JSON.stringify({ error: "No active Strava integration found" }),
      { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  let plainRefresh: string;
  try {
    plainRefresh = await decryptToken(
      (integration as { refresh_token: string }).refresh_token,
      encKey
    );
  } catch {
    return new Response(
      JSON.stringify({ error: "Failed to decrypt refresh token" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const refreshRes = await fetch("https://www.strava.com/oauth/token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: STRAVA_CLIENT_ID,
      client_secret: STRAVA_CLIENT_SECRET,
      grant_type: "refresh_token",
      refresh_token: plainRefresh,
    }),
  });

  if (!refreshRes.ok) {
    return new Response(
      JSON.stringify({ error: "Strava token refresh failed" }),
      { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const refreshed = await refreshRes.json();

  const encryptedAccess = await encryptToken(refreshed.access_token, encKey);
  const encryptedRefresh = await encryptToken(refreshed.refresh_token, encKey);

  const { error: updateError } = await supabase
    .from("integrations")
    .update({
      access_token: encryptedAccess,
      refresh_token: encryptedRefresh,
      token_expires_at: new Date(
        (refreshed.expires_at as number) * 1000
      ).toISOString(),
    })
    .eq("user_id", userId)
    .eq("provider", "strava");

  if (updateError) {
    return new Response(
      JSON.stringify({ error: "Failed to update tokens" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
