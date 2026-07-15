import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  createClient,
  SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";
import { ClerkAuthError, verifyClerkJWT } from "../_shared/clerk-auth.ts";

// delete-account — irreversible. Deletes ALL of a user's data across both
// keying schemes, then the users row itself, as service role.
//
// Security: this endpoint VERIFIES the Clerk JWT signature (see _shared/
// clerk-auth.ts) rather than merely decoding it, because a forged token here
// would let an attacker delete an arbitrary account. Requires CLERK_ISSUER.
//
// Idempotent: safe to re-run after a partial failure. If the users row is
// already gone, uuid-keyed deletes are skipped and text-keyed deletes (which
// only need the clerk id) still run, so orphans from an earlier partial run
// are cleaned up.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-clerk-token",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return respond({ error: "Method not allowed" }, 405);
  }

  const clerkToken = req.headers.get("x-clerk-token");
  if (!clerkToken) {
    return respond({ error: "Missing x-clerk-token" }, 401);
  }

  let clerkId: string;
  try {
    clerkId = await verifyClerkJWT(clerkToken);
  } catch (err) {
    if (err instanceof ClerkAuthError) {
      return respond({ error: "Unauthorized" }, 401);
    }
    console.error("JWT verification error:", (err as Error).message);
    return respond({ error: "Auth verification failed" }, 500);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    // Resolve the UUID that uuid-keyed tables store in user_id. On an
    // idempotent re-run the users row may already be gone (undefined) — that's
    // fine; uuid-keyed deletes are skipped and text-keyed deletes still run.
    const { data: userRow, error: userErr } = await supabase
      .from("users")
      .select("id")
      .eq("clerk_id", clerkId)
      .maybeSingle();
    if (userErr) throw new Error(`resolve user: ${userErr.message}`);
    const userUuid = userRow?.id as string | undefined;

    // ---- Text-keyed tables (user_id = Clerk text id) ----
    // Order: coach_messages before coach_conversations (messages.conversation_id
    // FK → conversations). meals is independent.
    await delBy(supabase, "coach_messages", "user_id", clerkId);
    await delBy(supabase, "coach_conversations", "user_id", clerkId);
    await delBy(supabase, "meals", "user_id", clerkId);

    // ---- UUID-keyed tables (user_id = users.id) ----
    // Order: macro_targets before training_sessions (macro_targets.session_id
    // FK → training_sessions). coach_conversations.session_id → training_sessions
    // is ON DELETE SET NULL, and conversations are already gone above anyway.
    // integrations last of the data tables — its deletion destroys the
    // AES-GCM-encrypted Strava tokens (rule 7 continuity through deletion).
    if (userUuid) {
      await delBy(supabase, "macro_targets", "user_id", userUuid);
      await delBy(supabase, "training_sessions", "user_id", userUuid);
      await delBy(supabase, "races", "user_id", userUuid);
      await delBy(supabase, "integrations", "user_id", userUuid);

      // ---- Finally the users row ----
      const { error } = await supabase.from("users").delete().eq("id", userUuid);
      if (error) throw new Error(`users: ${error.message}`);
    }

    return respond({ deleted: true }, 200);
  } catch (err) {
    // Do not leak the clerk id or internals to the client.
    console.error("delete-account failed:", (err as Error).message);
    return respond({ error: "Deletion failed" }, 500);
  }
});

async function delBy(
  supabase: SupabaseClient,
  table: string,
  column: string,
  value: string,
): Promise<void> {
  const { error } = await supabase.from(table).delete().eq(column, value);
  if (error) throw new Error(`${table}: ${error.message}`);
}

function respond(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
