// APNs push sender shared by strava-webhook (and any future push site).
//
// STUB STATUS: APNS_KEY / APNS_KEY_ID / APNS_TEAM_ID secrets are not yet
// configured on this project (no Apple Developer .p8 key has been generated,
// and the iOS target does not yet have the Push Notifications capability /
// aps-environment entitlement enabled). Rather than guess those values, this
// function checks for their presence and no-ops with a logged reason when
// they're absent. Once the real APNs key is created and the three secrets
// are set (`supabase secrets set APNS_KEY=... APNS_KEY_ID=... APNS_TEAM_ID=...`)
// and the Xcode capability/entitlement is enabled, this starts working with
// no code changes.

const APNS_KEY_PEM = Deno.env.get("APNS_KEY") ?? "";
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_USE_SANDBOX = Deno.env.get("APNS_USE_SANDBOX") === "true";
const APNS_BUNDLE_ID = "com.pyb99.crunch";

function base64UrlEncode(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function pemToPkcs8(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

async function signProviderToken(): Promise<string> {
  const header = { alg: "ES256", kid: APNS_KEY_ID };
  const claims = { iss: APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) };

  const encoder = new TextEncoder();
  const signingInput =
    base64UrlEncode(encoder.encode(JSON.stringify(header))) +
    "." +
    base64UrlEncode(encoder.encode(JSON.stringify(claims)));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(APNS_KEY_PEM),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(signingInput)
  );

  return `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;
}

/**
 * Sends a single alert push via APNs. Never throws — returns false and
 * console.error's the APNs status/reason on any failure, so callers can
 * treat push delivery as fire-and-forget.
 */
export async function sendPush(
  deviceToken: string,
  alert: { title?: string; body: string },
  payload: Record<string, unknown> = {}
): Promise<boolean> {
  if (!APNS_KEY_PEM || !APNS_KEY_ID || !APNS_TEAM_ID) {
    console.error(
      "sendPush: skipped — APNS_KEY/APNS_KEY_ID/APNS_TEAM_ID not configured"
    );
    return false;
  }

  if (!deviceToken) {
    console.error("sendPush: skipped — no device token");
    return false;
  }

  try {
    const jwt = await signProviderToken();
    const host = APNS_USE_SANDBOX
      ? "api.sandbox.push.apple.com"
      : "api.push.apple.com";

    const res = await fetch(`https://${host}/3/device/${deviceToken}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        aps: { alert, sound: "default" },
        ...payload,
      }),
    });

    if (!res.ok) {
      const reason = await res.text();
      console.error(`sendPush: APNs ${res.status}: ${reason}`);
      return false;
    }

    return true;
  } catch (e) {
    console.error(`sendPush: ${e instanceof Error ? e.message : String(e)}`);
    return false;
  }
}
