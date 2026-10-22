/**
 * PeleIA - Backend Proxy para a Gemini API (Cloudflare Worker)
 *
 * - GET  /config : parte pública da configuração remota (produtos, planos, cotas, textos).
 * - POST /       : tarefas 'vision', 'report' e 'quota' para um usuário autenticado.
 *
 * Prompts, modelo e limites vêm da configuração (KV, com fallback para a cópia embutida).
 * O app nunca envia prompt; envia só a foto, o perfil declarado e o resumo do comparativo.
 * LGPD: nunca registra foto, Base64, perfil ou observação do usuário em logs.
 */

import { loadConfig, publicConfig, type PeleiaConfig } from './config';
import { verifyFirebaseIdToken } from './auth';
import { fetchEntitlements, EntitlementLookupError, type Entitlements } from './revenuecat';
import {
  buildReportPrompt,
  buildVisionPrompt,
  normalizeAnalysis,
  parseModelJson,
  sanitizeProfile,
  sanitizeUserText,
} from './prompts';
import type { QuotaRequest } from './quota';

export { QuotaDurableObject } from './quota';

export interface Env {
  GEMINI_API_KEY: string;
  FIREBASE_PROJECT_ID?: string;
  REVENUECAT_SECRET_KEY?: string;
  PREMIUM_ENTITLEMENT_ID?: string;
  ALLOWED_ORIGINS?: string;
  ENVIRONMENT?: string;
  DEV_IS_PRO?: string;
  QUOTA_DO: DurableObjectNamespace;
  CONFIG_KV?: KVNamespace;
}

// Payload completo (JSON com a imagem em Base64, ~1.5MB de imagem original).
export const MAX_REQUEST_BYTES = 2_500_000;
const VISION_TIMEOUT_MS = 40_000;
const REPORT_TIMEOUT_MS = 50_000;

class HttpError extends Error {
  constructor(public status: number, public body: Record<string, unknown>) {
    super(String(body.error ?? status));
  }
}

function corsHeaders(request: Request, env: Env, isPublic: boolean): Record<string, string> {
  const headers: Record<string, string> = {
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-App-Build, If-None-Match',
    'Access-Control-Expose-Headers': 'ETag',
    Vary: 'Origin',
  };
  const origin = request.headers.get('Origin');
  const allowed = (env.ALLOWED_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean);
  if (isPublic) headers['Access-Control-Allow-Origin'] = '*';
  else if (origin && allowed.includes(origin)) headers['Access-Control-Allow-Origin'] = origin;
  return headers;
}

function jsonResponse(body: unknown, status: number, cors: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

export function saoPauloDay(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

async function sha1Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function readBoundedStream(
  stream: ReadableStream | null,
  maxBytes: number,
): Promise<{ buffer: Uint8Array; error?: string }> {
  if (!stream) return { buffer: new Uint8Array(0) };

  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maxBytes) {
        await reader.cancel('PAYLOAD_TOO_LARGE');
        return { buffer: new Uint8Array(0), error: 'Payload excede o limite máximo permitido de 2.5MB.' };
      }
      chunks.push(value);
    }
  } catch (err: any) {
    return { buffer: new Uint8Array(0), error: err.message };
  }

  const assembled = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    assembled.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return { buffer: assembled };
}

async function authenticate(request: Request, env: Env): Promise<string> {
  const authHeader = request.headers.get('Authorization');
  const isDev = env.ENVIRONMENT === 'development';

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    if (isDev) return 'dev-local';
    throw new HttpError(401, { error: 'Token de autenticação não fornecido ou formato inválido.' });
  }
  if (!env.FIREBASE_PROJECT_ID) {
    if (isDev) return 'dev-local';
    console.error('[Proxy] FIREBASE_PROJECT_ID não configurado.');
    throw new HttpError(500, { error: 'Servidor sem configuração de autenticação.' });
  }

  const uid = await verifyFirebaseIdToken(authHeader.slice('Bearer '.length).trim(), env.FIREBASE_PROJECT_ID);
  if (!uid) throw new HttpError(403, { error: 'Token expirado ou inválido. Autentique-se novamente no app.' });
  return uid;
}

async function entitlementsFor(uid: string, env: Env, config: PeleiaConfig): Promise<Entitlements> {
  if (uid === 'dev-local') return { isPro: env.DEV_IS_PRO === 'true', sosPurchased: 0 };
  try {
    return await fetchEntitlements(uid, env.REVENUECAT_SECRET_KEY, env.PREMIUM_ENTITLEMENT_ID || 'premium', config);
  } catch (err) {
    if (err instanceof EntitlementLookupError) {
      console.error(`[Proxy] ${err.message}`);
      throw new HttpError(503, { error: 'Não foi possível verificar sua assinatura agora. Tente novamente.' });
    }
    throw err;
  }
}

async function callQuota(stub: DurableObjectStub, path: string, body: QuotaRequest): Promise<Response> {
  return stub.fetch(`http://quota${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

async function callGemini(
  env: Env,
  model: string,
  parts: unknown[],
  generationConfig: Record<string, unknown>,
  timeoutMs: number,
): Promise<string | null> {
  let res: Response;
  try {
    res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
        body: JSON.stringify({ contents: [{ parts }], generationConfig }),
        signal: AbortSignal.timeout(timeoutMs),
      },
    );
  } catch (err: any) {
    console.error(`[Proxy Error] Gemini sem resposta: ${err?.name ?? 'erro'}`);
    return null;
  }

  if (!res.ok) {
    const errorText = await res.text();
    console.error(`[Proxy Error] Gemini retornou ${res.status}: ${errorText.slice(0, 120)}`);
    return null;
  }
  const data = (await res.json()) as any;
  return data.candidates?.[0]?.content?.parts?.[0]?.text || null;
}

async function handleConfig(request: Request, env: Env): Promise<Response> {
  const cors = corsHeaders(request, env, true);
  const config = await loadConfig(env.CONFIG_KV);
  const body = JSON.stringify(publicConfig(config));
  const etag = `"${await sha1Hex(body)}"`;
  const headers = { ...cors, ETag: etag, 'Cache-Control': 'public, max-age=300' };

  if (request.headers.get('If-None-Match') === etag) {
    return new Response(null, { status: 304, headers });
  }
  return new Response(body, { status: 200, headers: { ...headers, 'Content-Type': 'application/json' } });
}

async function handleTask(request: Request, env: Env, cors: Record<string, string>): Promise<Response> {
  const declaredLength = Number(request.headers.get('Content-Length') || '0');
  if (declaredLength > MAX_REQUEST_BYTES) {
    throw new HttpError(413, { error: 'Payload excede o limite máximo permitido de 2.5MB.' });
  }

  const uid = await authenticate(request, env);
  const config = await loadConfig(env.CONFIG_KV);

  const appBuild = Number(request.headers.get('X-App-Build') || '0');
  if (!(appBuild >= config.min_app_build)) {
    throw new HttpError(426, {
      code: 'APP_UPDATE_REQUIRED',
      error: 'Atualize o PeleIA na Google Play para continuar analisando.',
    });
  }

  const readResult = await readBoundedStream(request.body, MAX_REQUEST_BYTES);
  if (readResult.error) throw new HttpError(413, { error: readResult.error });

  let body: Record<string, any>;
  try {
    body = JSON.parse(new TextDecoder().decode(readResult.buffer));
  } catch {
    throw new HttpError(400, { error: 'Requisição inválida.' });
  }

  const stub = env.QUOTA_DO.get(env.QUOTA_DO.idFromName(uid));
  const day = saoPauloDay();
  const profile = sanitizeProfile(body.profile, config);

  if (body.task === 'quota') {
    const ent = await entitlementsFor(uid, env, config);
    const res = await callQuota(stub, '/status', {
      limits: config.quota, isPro: ent.isPro, sosPurchased: ent.sosPurchased, day,
    });
    return jsonResponse(await res.json(), 200, cors);
  }

  if (body.task === 'vision') {
    if (typeof body.image_base64 !== 'string' || body.image_base64.length === 0) {
      throw new HttpError(400, { error: 'Requisição inválida: envie a imagem.' });
    }

    const ent = await entitlementsFor(uid, env, config);
    const analysisId = crypto.randomUUID();
    const quotaReq: QuotaRequest = {
      limits: config.quota, isPro: ent.isPro, sosPurchased: ent.sosPurchased, day, analysisId,
    };

    const reserveRes = await callQuota(stub, '/reserve', quotaReq);
    if (!reserveRes.ok) return jsonResponse(await reserveRes.json(), reserveRes.status, cors);
    const reservation = (await reserveRes.json()) as Record<string, unknown>;

    console.log(`[Proxy] vision para UID ${uid.slice(0, 6)}***`);

    const rollback = () => callQuota(stub, '/rollback', quotaReq);

    const text = await callGemini(
      env,
      config.server.model,
      [
        { text: buildVisionPrompt(config, profile) },
        { inline_data: { mime_type: 'image/jpeg', data: body.image_base64 } },
      ],
      { temperature: 0.2, maxOutputTokens: 1024, responseMimeType: 'application/json' },
      VISION_TIMEOUT_MS,
    );
    if (!text) {
      await rollback();
      throw new HttpError(502, { error: 'Erro de processamento pelo provedor de IA. Tente novamente.' });
    }

    let parsed: any;
    try {
      parsed = parseModelJson(text);
    } catch {
      await rollback();
      throw new HttpError(502, { error: 'A IA retornou uma resposta inválida. Tente novamente.' });
    }

    if (parsed && typeof parsed.error === 'string') {
      await rollback();
      throw new HttpError(422, { code: 'PHOTO_REJECTED', error: sanitizeUserText(parsed.error, 200) });
    }

    const analysis = normalizeAnalysis(parsed);
    await callQuota(stub, '/store', { ...quotaReq, analysis });

    return jsonResponse({ success: true, analysis_id: analysisId, analysis, quota: reservation }, 200, cors);
  }

  if (body.task === 'report') {
    if (typeof body.analysis_id !== 'string') {
      throw new HttpError(400, { error: 'Requisição inválida: análise ausente.' });
    }
    const quotaReq: QuotaRequest = {
      limits: config.quota, isPro: false, sosPurchased: 0, day, analysisId: body.analysis_id,
    };

    const claimRes = await callQuota(stub, '/claim-report', quotaReq);
    if (!claimRes.ok) return jsonResponse(await claimRes.json(), claimRes.status, cors);
    const { analysis } = (await claimRes.json()) as { analysis: any };

    console.log(`[Proxy] report para UID ${uid.slice(0, 6)}***`);

    const text = await callGemini(
      env,
      config.server.model,
      [{ text: buildReportPrompt(config, profile, analysis, body.comparison_summary) }],
      { temperature: 0.7, maxOutputTokens: 2048 },
      REPORT_TIMEOUT_MS,
    );
    if (!text) {
      throw new HttpError(502, { error: 'Erro ao gerar o relatório. Tente novamente.' });
    }

    await callQuota(stub, '/complete-report', quotaReq);
    return jsonResponse({ success: true, output: text }, 200, cors);
  }

  throw new HttpError(400, { error: 'Tarefa desconhecida.' });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const path = new URL(request.url).pathname;
    const isConfig = path === '/config';
    const cors = corsHeaders(request, env, isConfig);

    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });

    try {
      if (isConfig) {
        if (request.method !== 'GET') return jsonResponse({ error: 'Método não permitido' }, 405, cors);
        return await handleConfig(request, env);
      }
      if (path !== '/') return jsonResponse({ error: 'Não encontrado' }, 404, cors);
      if (request.method !== 'POST') return jsonResponse({ error: 'Método não permitido' }, 405, cors);
      return await handleTask(request, env, cors);
    } catch (err: any) {
      if (err instanceof HttpError) return jsonResponse(err.body, err.status, cors);
      console.error('[Proxy Fatal]', err?.message);
      return jsonResponse({ error: 'Falha interna de comunicação no servidor seguro.' }, 500, cors);
    }
  },
};
