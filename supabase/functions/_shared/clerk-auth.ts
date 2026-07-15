// Clerk JWT verification for destructive / privileged Edge Functions.
//
// Unlike coach-respond / strava-oauth (which only *decode* the token to read
// the `sub` claim), this VERIFIES the RS256 signature against Clerk's published
// JWKS before trusting the identity. Use it on any endpoint where a forged
// token would cause irreversible harm — e.g. delete-account.
//
// Requires the CLERK_ISSUER env var: the Clerk Frontend API / issuer URL, e.g.
// "https://clerk.your-app.com" or "https://<slug>.clerk.accounts.dev". Find it
// in the Clerk dashboard (API Keys → "Frontend API URL") or as the `iss` claim
// of any session token. This is a public value, not a secret; it pins which
// issuer we trust so a token minted by a *different* Clerk instance cannot be
// replayed here. If it is unset, verification fails closed (throws).

interface Jwk {
  kid: string;
  kty: string;
  n: string;
  e: string;
  alg?: string;
  use?: string;
}

// Module-scope JWKS cache. Edge Function instances are short-lived, so a small
// TTL avoids re-fetching JWKS on every request without risking stale keys past
// a rotation for long.
let cachedKeys: { keys: Jwk[]; fetchedAt: number } | null = null;
const JWKS_TTL_MS = 10 * 60 * 1000; // 10 minutes

export class ClerkAuthError extends Error {}

function base64UrlToUint8Array(b64url: string): Uint8Array {
  const b64 = b64url.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function decodeJsonSegment(b64url: string): Record<string, unknown> {
  const text = new TextDecoder().decode(base64UrlToUint8Array(b64url));
  return JSON.parse(text);
}

async function getJwks(issuer: string, forceRefresh = false): Promise<Jwk[]> {
  if (
    !forceRefresh &&
    cachedKeys &&
    Date.now() - cachedKeys.fetchedAt < JWKS_TTL_MS
  ) {
    return cachedKeys.keys;
  }
  const res = await fetch(`${issuer}/.well-known/jwks.json`);
  if (!res.ok) throw new ClerkAuthError(`JWKS fetch failed: ${res.status}`);
  const data = await res.json();
  const keys = (data.keys ?? []) as Jwk[];
  cachedKeys = { keys, fetchedAt: Date.now() };
  return keys;
}

// Verifies signature + standard claims (iss, exp, nbf). Returns the Clerk user
// id (`sub`) on success; throws ClerkAuthError on any failure. Never returns an
// unverified identity.
export async function verifyClerkJWT(token: string): Promise<string> {
  const issuer = Deno.env.get("CLERK_ISSUER");
  if (!issuer) {
    // Fail closed: without a pinned issuer we cannot safely verify.
    throw new ClerkAuthError("CLERK_ISSUER not configured");
  }

  const parts = token.split(".");
  if (parts.length !== 3) throw new ClerkAuthError("Malformed token");
  const [headerB64, payloadB64, sigB64] = parts;

  let header: Record<string, unknown>;
  let payload: Record<string, unknown>;
  try {
    header = decodeJsonSegment(headerB64);
    payload = decodeJsonSegment(payloadB64);
  } catch {
    throw new ClerkAuthError("Undecodable token");
  }

  if (header.alg !== "RS256") throw new ClerkAuthError("Unexpected alg");
  const kid = header.kid as string | undefined;
  if (!kid) throw new ClerkAuthError("Missing kid");

  // Issuer must match the pinned Clerk instance.
  if (payload.iss !== issuer) throw new ClerkAuthError("Issuer mismatch");

  const now = Math.floor(Date.now() / 1000);
  const skew = 5; // seconds of clock-skew tolerance
  if (typeof payload.exp === "number" && now > payload.exp + skew) {
    throw new ClerkAuthError("Token expired");
  }
  if (typeof payload.nbf === "number" && now + skew < payload.nbf) {
    throw new ClerkAuthError("Token not yet valid");
  }

  const sub = payload.sub;
  if (typeof sub !== "string" || sub.length === 0) {
    throw new ClerkAuthError("Missing sub");
  }

  // Find the signing key by kid; refresh JWKS once on a miss (key rotation).
  let keys = await getJwks(issuer);
  let jwk = keys.find((k) => k.kid === kid);
  if (!jwk) {
    keys = await getJwks(issuer, true);
    jwk = keys.find((k) => k.kid === kid);
  }
  if (!jwk) throw new ClerkAuthError("Unknown signing key");

  const cryptoKey = await crypto.subtle.importKey(
    "jwk",
    { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    base64UrlToUint8Array(sigB64),
    new TextEncoder().encode(`${headerB64}.${payloadB64}`),
  );
  if (!valid) throw new ClerkAuthError("Bad signature");

  return sub;
}
