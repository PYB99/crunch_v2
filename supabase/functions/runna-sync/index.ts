import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { generateAndSaveMacroTarget } from "../_shared/macroEngine.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// ── iCal types ────────────────────────────────────────────────────────────────

interface ICalEvent {
  uid: string;
  dtstart: string;
  dtend: string | null;
  summary: string;
}

// ── iCal parser ───────────────────────────────────────────────────────────────

function unfoldLines(text: string): string[] {
  const raw = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
  const out: string[] = [];
  for (const line of raw) {
    if ((line.startsWith(" ") || line.startsWith("\t")) && out.length > 0) {
      out[out.length - 1] += line.slice(1);
    } else {
      out.push(line);
    }
  }
  return out;
}

function unescapeText(value: string): string {
  return value
    .replace(/\\,/g, ",")
    .replace(/\\;/g, ";")
    .replace(/\\n/gi, " ")
    .replace(/\\\\/g, "\\");
}

function parseIcal(text: string): ICalEvent[] {
  const lines = unfoldLines(text);
  const events: ICalEvent[] = [];
  let inEvent = false;
  let props: Record<string, string> = {};

  for (const line of lines) {
    if (line === "BEGIN:VEVENT") {
      inEvent = true;
      props = {};
    } else if (line === "END:VEVENT") {
      inEvent = false;
      if (props["UID"] && props["DTSTART"] && props["STATUS"] !== "CANCELLED") {
        events.push({
          uid: props["UID"],
          dtstart: props["DTSTART"],
          dtend: props["DTEND"] ?? null,
          summary: unescapeText(props["SUMMARY"] ?? ""),
        });
      }
    } else if (inEvent) {
      const colonIdx = line.indexOf(":");
      if (colonIdx === -1) continue;
      // Strip property parameters (e.g. DTSTART;TZID=America/New_York → DTSTART)
      const key = line.slice(0, colonIdx).split(";")[0];
      props[key] = line.slice(colonIdx + 1);
    }
  }

  return events;
}

// ── Date / duration helpers ───────────────────────────────────────────────────

function parseSessionDate(dtstart: string): string | null {
  const digits = dtstart.replace(/\D/g, "");
  if (digits.length < 8) return null;
  return `${digits.slice(0, 4)}-${digits.slice(4, 6)}-${digits.slice(6, 8)}`;
}

function parseIcalDatetime(value: string): Date | null {
  const d = value.replace(/\D/g, "");
  if (d.length < 14) return null;
  return new Date(
    Date.UTC(
      parseInt(d.slice(0, 4)),
      parseInt(d.slice(4, 6)) - 1,
      parseInt(d.slice(6, 8)),
      parseInt(d.slice(8, 10)),
      parseInt(d.slice(10, 12)),
      parseInt(d.slice(12, 14))
    )
  );
}

function calcDurationMins(dtstart: string, dtend: string | null): number | null {
  if (!dtend) return null;
  const start = parseIcalDatetime(dtstart);
  const end = parseIcalDatetime(dtend);
  if (!start || !end) return null;
  const diff = end.getTime() - start.getTime();
  return diff > 0 ? Math.round(diff / 60_000) : null;
}

// ── Session classification ────────────────────────────────────────────────────

function mapSessionType(summary: string): string {
  const s = summary.toLowerCase();
  if (s.includes("rest day") || s === "rest") return "rest";
  if (s.includes("long run") || s.includes("long easy")) return "long_run";
  if (s.includes("tempo") || s.includes("threshold")) return "tempo";
  if (
    s.includes("interval") ||
    s.includes("track") ||
    s.includes("speed") ||
    s.includes("fartlek")
  ) return "interval";
  return "easy_run";
}

function extractDistanceKm(summary: string): number | null {
  const match = summary.match(/(\d+(?:\.\d+)?)\s*km/i);
  return match ? parseFloat(match[1]) : null;
}

// ── Main handler ──────────────────────────────────────────────────────────────

serve(async (_req: Request) => {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  const { data: integrations, error: intError } = await supabase
    .from("integrations")
    .select("user_id, access_token")
    .eq("provider", "runna")
    .eq("is_active", true);

  if (intError) {
    return new Response(
      JSON.stringify({ error: "Failed to fetch integrations" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  if (!integrations || integrations.length === 0) {
    return new Response(
      JSON.stringify({ processed: 0, users: 0, errors: [] }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  }

  let totalSynced = 0;
  const errors: string[] = [];

  for (const row of integrations) {
    const { user_id, access_token: icalUrl } = row as {
      user_id: string;
      access_token: string;
    };

    try {
      // Fetch iCal feed with a 10-second timeout
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 10_000);
      let icalText: string;
      try {
        const res = await fetch(icalUrl, { signal: controller.signal });
        if (!res.ok) throw new Error(`iCal fetch returned HTTP ${res.status}`);
        icalText = await res.text();
      } finally {
        clearTimeout(timer);
      }

      const events = parseIcal(icalText);

      for (const event of events) {
        const sessionDate = parseSessionDate(event.dtstart);
        if (!sessionDate) continue;

        const sessionType = mapSessionType(event.summary);
        const { data: sessionRow, error: upsertError } = await supabase
          .from("training_sessions")
          .upsert(
            {
              user_id,
              source: "runna",
              session_date: sessionDate,
              session_type: sessionType,
              distance_km: extractDistanceKm(event.summary),
              duration_mins: calcDurationMins(event.dtstart, event.dtend),
              status: "planned",
              runna_uid: event.uid,
            },
            { onConflict: "user_id,runna_uid" }
          )
          .select("id")
          .single();

        if (!upsertError && sessionRow) {
          totalSynced++;
          try {
            await generateAndSaveMacroTarget(supabase, {
              userId: user_id,
              sessionId: (sessionRow as { id: string }).id,
              sessionDate,
              sessionType,
            });
          } catch {
            // Macro generation failure must not block session sync.
          }
        }
      }
    } catch (e) {
      errors.push(
        `user ${user_id}: ${e instanceof Error ? e.message : String(e)}`
      );
    }
  }

  return new Response(
    JSON.stringify({ processed: totalSynced, users: integrations.length, errors }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
});
