// Verificação de ID token do Firebase Auth (RS256, chaves públicas do Google).

export const FIREBASE_JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

const CLOCK_SKEW_SEC = 300;

let jwksCache: { keys: Map<string, CryptoKey>; expiresAt: number } | null = null;

export function resetJwksCache(): void {
  jwksCache = null;
}

function base64UrlToBytes(input: string): Uint8Array {
  const base64 = input.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function decodeJsonSegment(segment: string): any {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(segment)));
}

async function getSigningKey(kid: string): Promise<CryptoKey | null> {
  if (!jwksCache || Date.now() >= jwksCache.expiresAt || !jwksCache.keys.has(kid)) {
    const res = await fetch(FIREBASE_JWKS_URL);
    if (!res.ok) return null;

    const maxAge = /max-age=(\d+)/.exec(res.headers.get('Cache-Control') || '');
    const ttlMs = (maxAge ? Number(maxAge[1]) : 3600) * 1000;
    const { keys } = (await res.json()) as { keys: (JsonWebKey & { kid: string })[] };

    const map = new Map<string, CryptoKey>();
    for (const jwk of keys) {
      const key = await crypto.subtle.importKey(
        'jwk',
        jwk,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['verify'],
      );
      map.set(jwk.kid, key);
    }
    jwksCache = { keys: map, expiresAt: Date.now() + ttlMs };
  }
  return jwksCache.keys.get(kid) ?? null;
}

/** Retorna o uid do token se assinatura e claims forem válidos; caso contrário, null. */
export async function verifyFirebaseIdToken(token: string, projectId: string): Promise<string | null> {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const header = decodeJsonSegment(parts[0]);
    if (header.alg !== 'RS256' || typeof header.kid !== 'string') return null;

    const payload = decodeJsonSegment(parts[1]);
    const nowSec = Math.floor(Date.now() / 1000);
    if (typeof payload.exp !== 'number' || payload.exp <= nowSec) return null;
    if (typeof payload.iat !== 'number' || payload.iat > nowSec + CLOCK_SKEW_SEC) return null;
    if (payload.aud !== projectId) return null;
    if (payload.iss !== `https://securetoken.google.com/${projectId}`) return null;
    if (typeof payload.sub !== 'string' || payload.sub.length === 0 || payload.sub.length > 128) return null;

    const key = await getSigningKey(header.kid);
    if (!key) return null;

    const valid = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      key,
      base64UrlToBytes(parts[2]),
      new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
    );
    return valid ? payload.sub : null;
  } catch {
    return null;
  }
}
