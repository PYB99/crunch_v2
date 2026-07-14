import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

  // Extract Clerk JWT from custom header (Supabase gateway rejects RS256 in Authorization)
  const clerkToken = req.headers.get("x-clerk-token");
  if (!clerkToken) {
    return respond({ error: "Missing x-clerk-token" }, 401);
  }

  // Decode (not verify) the Clerk JWT to extract clerk_id
  let clerkId: string;
  try {
    const parts = clerkToken.split(".");
    if (parts.length !== 3) throw new Error("bad structure");
    const payload = JSON.parse(
      atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"))
    );
    if (!payload.sub) throw new Error("no sub");
    clerkId = payload.sub as string;
  } catch {
    return respond({ error: "Invalid token" }, 401);
  }

  // Parse body
  let body: { conversation_id?: string; message?: string };
  try {
    body = await req.json();
  } catch {
    return respond({ error: "Invalid JSON" }, 400);
  }

  const userMessage = (body.message ?? "")
    .replace(/<[^>]*>/g, "") // strip HTML
    .substring(0, 2000)
    .trim();

  if (!userMessage) {
    return respond({ error: "Message is required" }, 400);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Get or create conversation
  let conversationId = body.conversation_id ?? null;
  if (!conversationId) {
    const { data: newConv, error: convErr } = await supabase
      .from("coach_conversations")
      .insert({ user_id: clerkId })
      .select("id")
      .single();
    if (convErr || !newConv) {
      console.error("create conversation:", convErr?.message);
      return respond({ error: "Failed to create conversation" }, 500);
    }
    conversationId = newConv.id as string;
  }

  // Fetch user context + message history in parallel
  const [userRes, raceRes, mealsRes, historyRes] = await Promise.all([
    supabase
      .from("users")
      .select("height_cm, weight_kg, age, gender")
      .eq("clerk_id", clerkId)
      .maybeSingle(),
    supabase
      .from("races")
      .select("race_name, race_type, race_date")
      .eq("user_id", clerkId)
      .eq("is_active", true)
      .order("race_date", { ascending: true })
      .limit(1)
      .maybeSingle(),
    supabase
      .from("meals")
      .select("meal_name, meal_time")
      .eq("user_id", clerkId)
      .eq("is_active", true)
      .order("sort_order", { ascending: true }),
    supabase
      .from("coach_messages")
      .select("role, content")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: false })
      .limit(20),
  ]);

  const user = userRes.data;
  const race = raceRes.data;
  const meals = mealsRes.data ?? [];
  const history = (historyRes.data ?? []).reverse();

  // Training phase
  let weeksToRace: number | null = null;
  let trainingPhase = "Base Building";
  if (race?.race_date) {
    const ms = new Date(race.race_date).getTime() - Date.now();
    weeksToRace = Math.ceil(ms / (7 * 24 * 60 * 60 * 1000));
    if (weeksToRace <= 0) trainingPhase = "Race Week";
    else if (weeksToRace <= 4) trainingPhase = "Taper";
    else if (weeksToRace <= 8) trainingPhase = "Peak Training";
    else if (weeksToRace <= 12) trainingPhase = "Build";
    else trainingPhase = "Base Building";
  }

  // Meal library string
  const byTime: Record<string, string[]> = {};
  for (const m of meals) {
    (byTime[m.meal_time] ??= []).push(m.meal_name);
  }
  const mealLibrary =
    Object.entries(byTime)
      .map(([t, names]) => `${t}: ${names.join(", ")}`)
      .join(". ") || "No meals set up yet";

  const raceName =
    race?.race_name ||
    race?.race_type?.replace(/_/g, " ") ||
    "an upcoming race";
  const raceDistance =
    weeksToRace !== null ? `${weeksToRace} weeks away` : "date not set";
  const bio = `${user?.height_cm ?? 175}cm / ${user?.weight_kg ?? 70}kg / ${user?.age ?? 30} years old / ${user?.gender ?? "male"}`;

  const systemPrompt =
    `You are a sports nutritionist specialising in endurance running. You know this runner ` +
    `personally: their race is ${raceName}, ${raceDistance}, in ${trainingPhase} phase. ` +
    `Their usual meals: ${mealLibrary}. Biometrics: ${bio}.\n\n` +
    `Speak conversationally — like a running mate who knows nutrition. Reference their actual meals by name. ` +
    `Never give generic advice. Never mention calories, deficits, or body composition. ` +
    `Anchor to their race and training. Use portions and real food.`;

  const claudeMessages = [
    ...history.map((m) => ({
      role: m.role as "user" | "assistant",
      content: m.content as string,
    })),
    { role: "user" as const, content: userMessage },
  ];

  // Call Claude
  const claudeRes = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 500,
      system: systemPrompt,
      messages: claudeMessages,
    }),
  });

  if (!claudeRes.ok) {
    const errText = await claudeRes.text();
    console.error("Claude API error:", errText);
    return respond({ error: "AI service unavailable" }, 502);
  }

  const claudeData = await claudeRes.json();
  const assistantContent = claudeData.content?.[0]?.text as string | undefined;
  if (!assistantContent) {
    return respond({ error: "Empty AI response" }, 502);
  }

  // Save both messages
  const [, assistantRes] = await Promise.all([
    supabase.from("coach_messages").insert({
      conversation_id: conversationId,
      user_id: clerkId,
      role: "user",
      content: userMessage,
    }),
    supabase
      .from("coach_messages")
      .insert({
        conversation_id: conversationId,
        user_id: clerkId,
        role: "assistant",
        content: assistantContent,
      })
      .select("id, created_at")
      .single(),
  ]);

  // Bump conversation timestamp
  await supabase
    .from("coach_conversations")
    .update({ updated_at: new Date().toISOString() })
    .eq("id", conversationId);

  if (assistantRes.error || !assistantRes.data) {
    console.error("save assistant msg:", assistantRes.error?.message);
    return respond({ error: "Failed to save response" }, 500);
  }

  return respond(
    {
      conversation_id: conversationId,
      message_id: assistantRes.data.id,
      content: assistantContent,
      user_id: clerkId,
      created_at: assistantRes.data.created_at,
    },
    200
  );
});

function respond(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}
