import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

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

  // Verify identity via Clerk JWT
  const clerkToken = req.headers.get("x-clerk-token");
  if (!clerkToken) {
    return respond({ error: "Missing x-clerk-token" }, 401);
  }
  try {
    const parts = clerkToken.split(".");
    if (parts.length !== 3) throw new Error("bad structure");
    const payload = JSON.parse(
      atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"))
    );
    if (!payload.sub) throw new Error("no sub");
  } catch {
    return respond({ error: "Invalid token" }, 401);
  }

  let body: { description?: string };
  try {
    body = await req.json();
  } catch {
    return respond({ error: "Invalid JSON" }, 400);
  }

  const description = (body.description ?? "")
    .replace(/<[^>]*>/g, "")
    .substring(0, 500)
    .trim();

  if (!description) {
    return respond({ error: "description is required" }, 400);
  }

  const claudeRes = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 300,
      system:
        "You are a sports nutritionist. Estimate the macronutrient content of this meal. " +
        'Return ONLY a JSON object: {"carbs_g": number, "protein_g": number, "fat_g": number} ' +
        "Values are grams for one normal serving. No other text.",
      messages: [{ role: "user", content: description }],
    }),
  });

  if (!claudeRes.ok) {
    const errText = await claudeRes.text();
    console.error("Claude API error:", errText);
    return respond({ error: "AI service unavailable" }, 502);
  }

  const claudeData = await claudeRes.json();
  const rawText: string = claudeData.content?.[0]?.text ?? "";

  // Strip markdown code fences if present
  const stripped = rawText
    .replace(/```[a-z]*\n?/gi, "")
    .replace(/```/g, "")
    .trim();

  let macros: { carbs_g: unknown; protein_g: unknown; fat_g: unknown };
  try {
    macros = JSON.parse(stripped);
  } catch {
    return respond({ error: "AI returned invalid format" }, 502);
  }

  if (
    typeof macros.carbs_g !== "number" || macros.carbs_g <= 0 ||
    typeof macros.protein_g !== "number" || macros.protein_g <= 0 ||
    typeof macros.fat_g !== "number" || macros.fat_g <= 0
  ) {
    return respond({ error: "AI returned invalid macro values" }, 502);
  }

  return respond(
    {
      carbs_g: macros.carbs_g,
      protein_g: macros.protein_g,
      fat_g: macros.fat_g,
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
