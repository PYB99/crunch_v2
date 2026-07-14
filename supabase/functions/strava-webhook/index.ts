import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  decryptToken,
  encryptToken,
  importEncryptionKey,
} from "../_shared/token-crypto.ts";
import { generateAndSaveMacroTarget } from "../_shared/macroEngine.ts";
import { sendPush } from "../_shared/apns.ts";

const VERIFY_TOKEN = Deno.env.get("STRAVA_WEBHOOK_VERIFY_TOKEN") ?? "";
const STRAVA_CLIENT_ID = Deno.env.get("STRAVA_CLIENT_ID") ?? "";
const STRAVA_CLIENT_SECRET = Deno.env.get("STRAVA_CLIENT_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ENCRYPTION_KEY_B64 = Deno.env.get("INTEGRATION_ENCRYPTION_KEY") ?? "";

// workout_type integer mapping for Run activities.
// Community-confirmed values — not formally documented by Strava.
// Verify these are still correct if Strava API behaviour changes.
const WORKOUT_TYPE_MAP: Record<number, string> = {
  0: "easy_run",
  1: "race",
  2: "long_run",
  3: "tempo",
};

function mapSessionType(workoutType: number | null | undefined): string {
  if (workoutType == null) return "easy_run";
  return WORKOUT_TYPE_MAP[workoutType] ?? "easy_run";
}

async function refreshStravaToken(refreshToken: string): Promise<{
  access_token: string;
  refresh_token: string;
  expires_at: number;
}> {
  const res = await fetch("https://www.strava.com/oauth/token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: STRAVA_CLIENT_ID,
      client_secret: STRAVA_CLIENT_SECRET,
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    }),
  });

  if (!res.ok) {
    throw new Error(`Strava token refresh failed: ${res.status}`);
  }

  const data = await res.json();
  return {
    access_token: data.access_token,
    refresh_token: data.refresh_token,
    expires_at: data.expires_at as number,
  };
}

serve(async (req: Request) => {
  const url = new URL(req.url);

  // ── GET: webhook subscription verification ───────────────────────────────
  if (req.method === "GET") {
    const mode = url.searchParams.get("hub.mode");
    const challenge = url.searchParams.get("hub.challenge");
    const verifyToken = url.searchParams.get("hub.verify_token");

    if (mode !== "subscribe" || verifyToken !== VERIFY_TOKEN) {
      return new Response("Forbidden", { status: 403 });
    }

    return new Response(JSON.stringify({ "hub.challenge": challenge }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ── POST: activity event ─────────────────────────────────────────────────
  if (req.method === "POST") {
    let body: {
      object_type: string;
      aspect_type: string;
      object_id: number;
      owner_id: number;
    };

    try {
      body = await req.json();
    } catch {
      return new Response("Bad Request", { status: 400 });
    }

    const { object_type, aspect_type, object_id, owner_id } = body;

    // Strava requires 200 even for events we choose not to process
    if (object_type !== "activity") {
      return new Response("OK", { status: 200 });
    }

    // Only handle creates — update/delete support deferred to a later phase
    if (aspect_type !== "create") {
      return new Response("OK", { status: 200 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Resolve Strava athlete ID → Crunch user
    const { data: integration, error: integrationError } = await supabase
      .from("integrations")
      .select("user_id, access_token, refresh_token, token_expires_at")
      .eq("provider", "strava")
      .eq("provider_user_id", String(owner_id))
      .eq("is_active", true)
      .single();

    if (integrationError || !integration) {
      return new Response("OK", { status: 200 });
    }

    let { access_token, refresh_token, token_expires_at } = integration as {
      user_id: string;
      access_token: string;
      refresh_token: string;
      token_expires_at: string | null;
    };
    const userId = (integration as { user_id: string }).user_id;

    // Decrypt tokens stored at rest — both are AES-GCM encrypted
    const encKey = await importEncryptionKey(ENCRYPTION_KEY_B64);
    try {
      access_token = await decryptToken(access_token, encKey);
      refresh_token = await decryptToken(refresh_token, encKey);
    } catch {
      return new Response("OK", { status: 200 });
    }

    // Refresh token if it expires within the next 60 seconds
    const nowSeconds = Math.floor(Date.now() / 1000);
    const expiresAtSeconds = token_expires_at
      ? Math.floor(new Date(token_expires_at).getTime() / 1000)
      : 0;

    if (expiresAtSeconds - nowSeconds < 60) {
      try {
        const refreshed = await refreshStravaToken(refresh_token);
        access_token = refreshed.access_token;
        refresh_token = refreshed.refresh_token;

        const encAccess = await encryptToken(refreshed.access_token, encKey);
        const encRefresh = await encryptToken(refreshed.refresh_token, encKey);

        await supabase
          .from("integrations")
          .update({
            access_token: encAccess,
            refresh_token: encRefresh,
            token_expires_at: new Date(
              refreshed.expires_at * 1000
            ).toISOString(),
          })
          .eq("provider", "strava")
          .eq("provider_user_id", String(owner_id));
      } catch {
        // Cannot refresh — activity will be missed this event cycle
        return new Response("OK", { status: 200 });
      }
    }

    // Fetch full activity detail from Strava
    const activityRes = await fetch(
      `https://www.strava.com/api/v3/activities/${object_id}`,
      { headers: { Authorization: `Bearer ${access_token}` } }
    );

    if (!activityRes.ok) {
      return new Response("OK", { status: 200 });
    }

    const activity = await activityRes.json();

    // Only store runs — ignore rides, swims, hikes, etc.
    if (activity.type !== "Run") {
      return new Response("OK", { status: 200 });
    }

    const sessionType = mapSessionType(
      activity.workout_type as number | null
    );
    const distanceKm = (activity.distance as number) / 1000;
    const durationMins = Math.round((activity.moving_time as number) / 60);
    // start_date_local is the local clock time expressed as if UTC — take date part only
    const sessionDate = (activity.start_date_local as string).substring(0, 10);
    const perceivedExertion =
      (activity.perceived_exertion as number | null) ?? null;

    const { data: sessionRow } = await supabase
      .from("training_sessions")
      .upsert(
        {
          user_id: userId,
          source: "strava",
          session_date: sessionDate,
          session_type: sessionType,
          distance_km: distanceKm,
          duration_mins: durationMins,
          status: "completed",
          strava_activity_id: String(object_id),
          perceived_exertion: perceivedExertion,
        },
        { onConflict: "user_id,strava_activity_id" }
      )
      .select("id")
      .single();

    if (sessionRow) {
      try {
        await generateAndSaveMacroTarget(supabase, {
          userId,
          sessionId: (sessionRow as { id: string }).id,
          sessionDate,
          sessionType,
        });
      } catch {
        // Macro generation failure must not prevent the 200 response to Strava.
      }

      // Auto-create the Coach conversation + first message, then push.
      // Every step here is best-effort — none may prevent the 200 to Strava.
      try {
        const newSessionId = (sessionRow as { id: string }).id;

        const { data: userData } = await supabase
          .from("users")
          .select("clerk_id, apns_device_token")
          .eq("id", userId)
          .maybeSingle();

        const clerkId = (userData as { clerk_id?: string } | null)?.clerk_id;
        const pushToken = (userData as { apns_device_token?: string | null } | null)
          ?.apns_device_token;

        if (clerkId) {
          // Dedupe: Strava may redeliver the same event.
          const { data: existingConv } = await supabase
            .from("coach_conversations")
            .select("id")
            .eq("session_id", newSessionId)
            .maybeSingle();

          if (!existingConv) {
            const { data: dinnerMeal } = await supabase
              .from("meals")
              .select("meal_name")
              .eq("user_id", clerkId)
              .eq("meal_time", "dinner")
              .eq("is_active", true)
              .order("sort_order", { ascending: true })
              .limit(1)
              .maybeSingle();

            const { data: newConv } = await supabase
              .from("coach_conversations")
              .insert({ user_id: clerkId, session_id: newSessionId })
              .select("id")
              .single();

            if (newConv) {
              const conversationId = (newConv as { id: string }).id;
              const typeLabel = sessionType.replace(/_/g, " ");
              const distanceLabel =
                distanceKm > 0 ? `${Math.round(distanceKm)}K ` : "";
              const dinnerName = (dinnerMeal as { meal_name?: string } | null)
                ?.meal_name;

              let firstMessage = `Nice work on that ${distanceLabel}${typeLabel}! How did it feel?`;
              if (dinnerName) {
                firstMessage += ` If you're refueling now, your usual ${dinnerName} is the right move — protein first, then carbs to refill.`;
              }

              await supabase.from("coach_messages").insert({
                conversation_id: conversationId,
                user_id: clerkId,
                role: "assistant",
                content: firstMessage,
              });

              if (pushToken) {
                await sendPush(
                  pushToken,
                  {
                    body: `Nice work on that ${Math.round(distanceKm)}K — how did it feel?`,
                  },
                  { conversation_id: conversationId }
                );
              }
            }
          }
        }
      } catch {
        // Coach conversation / push failure is non-fatal.
      }
    }

    return new Response("OK", { status: 200 });
  }

  return new Response("Method Not Allowed", { status: 405 });
});
