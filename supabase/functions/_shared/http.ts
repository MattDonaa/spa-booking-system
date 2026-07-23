// ============================================================================
// Small HTTP helpers shared by the payment Edge Functions.
// ============================================================================

export function json(
  body: unknown,
  status = 200,
  headers: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  });
}

export function ok(data: unknown, status = 200): Response {
  return json({ ok: true, data }, status);
}

export function error(code: string, message: string, status = 400): Response {
  return json({ ok: false, error: { code, message } }, status);
}

/** Read the raw request body once (needed before signature verification). */
export async function readRawBody(req: Request): Promise<string> {
  return await req.text();
}

/** Parse a urlencoded body (form POST) into a plain object. */
export function parseFormEncoded(raw: string): Record<string, string> {
  const params = new URLSearchParams(raw);
  const out: Record<string, string> = {};
  for (const [k, v] of params.entries()) out[k] = v;
  return out;
}

/** Require an environment variable, throwing a clear error if it is missing. */
export function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}
