import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Clerk JWTs are RS256; Supabase gateway rejects them in Authorization with
  // UNAUTHORIZED_ASYMMETRIC_JWT. The iOS client passes its Supabase anon key in
  // Authorization (accepted by the gateway) and the Clerk JWT in x-clerk-token.
  const jwt = req.headers.get("x-clerk-token");
  if (!jwt) {
    return new Response(JSON.stringify({ error: "Missing x-clerk-token" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Decode Clerk JWT to extract sub (clerk_id) and email.
  // Signature verification happens at the RLS layer via requesting_user_id().
  let clerkId: string;
  let email: string | null;
  try {
    const parts = jwt.split(".");
    if (parts.length !== 3) throw new Error("Invalid JWT structure");
    const payload = JSON.parse(
      atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"))
    );
    if (!payload.sub) throw new Error("No sub claim");
    clerkId = payload.sub;
    email = payload.email ?? payload.primary_email_address ?? null;
  } catch (err) {
    console.error("JWT decode failed:", err);
    return new Response(JSON.stringify({ error: "Invalid token" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Service role bypasses RLS — required because no users row exists yet.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Insert new row; if it already exists return the existing id without overwriting fields.
  const { data: inserted, error: insertError } = await supabase
    .from("users")
    .insert({
      clerk_id: clerkId,
      email: email,
      has_completed_onboarding: false,
    })
    .select("id")
    .maybeSingle();

  if (insertError && insertError.code !== "23505") {
    console.error("insert error:", insertError.message);
    return new Response(JSON.stringify({ error: "Database error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // If insert was a no-op (duplicate clerk_id), fetch the existing row's id.
  let userId: string;
  if (inserted) {
    userId = inserted.id;
  } else {
    const { data: existing, error: fetchError } = await supabase
      .from("users")
      .select("id")
      .eq("clerk_id", clerkId)
      .single();

    if (fetchError || !existing) {
      console.error("fetch existing user error:", fetchError?.message);
      return new Response(JSON.stringify({ error: "Database error" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    userId = existing.id;
  }

  console.log(`create-user-profile: clerk_id=${clerkId} → users.id=${userId}`);
  return new Response(JSON.stringify({ id: userId }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
