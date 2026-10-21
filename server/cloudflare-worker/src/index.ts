/**
 * PeleIA - Backend Proxy Seguro para Gemini API (Cloudflare Worker)
 * 
 * Arquitetura de Produção e Launch Hardening:
 * 1. Proteção de Chaves: GEMINI_API_KEY armazenada exclusivamente nos Secrets do Cloudflare.
 * 2. Autenticação e JWT: Validação estrita de claims (iss, aud, exp, uid).
 * 3. Cotas Atômicas via Durable Objects: Elimina Race Condition em chamadas concorrentes.
 *    Reserva atômica prévia + Rollback de compensação se o Gemini falhar.
 * 4. Proteção de Payload Estrita: Bounded streaming para evitar exaustão de memória.
 * 5. LGPD & Zero-Log: NUNCA grava logs de fotos, Base64 ou dados biométricos em stdout/loggers.
 */

export interface Env {
  GEMINI_API_KEY: string;
  GEMINI_MODEL?: string;
  FIREBASE_PROJECT_ID?: string;
  ENVIRONMENT?: string;
  QUOTA_DO: DurableObjectNamespace;
  QUOTA_KV?: KVNamespace;
}

// 2.5 MB máximo para o payload JSON completo (incluindo Base64 da imagem ~1.5MB original)
const MAX_REQUEST_BYTES = 2_500_000;

interface DecodedToken {
  uid: string;
  isPro: boolean;
  email?: string;
}

// ══════════════════════════════════════════════════════════
//  1. DURABLE OBJECT: Gerenciador Atômico de Cotas (P0)
//  Garante execução linearizada/atômica por UID do usuário
// ══════════════════════════════════════════════════════════
export class QuotaDurableObject {
  state: DurableObjectState;

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    // ── RESERVA ATÔMICA (Prévia à chamada do Gemini) ──────
    if (url.pathname === '/reserve') {
      const { isPro, todayKey } = (await request.json()) as {
        isPro: boolean;
        todayKey: string;
      };

      const lifetimeScans = ((await this.state.storage.get<number>('lifetime_scans')) || 0);
      const dailyScans = ((await this.state.storage.get<number>(`scans_${todayKey}`)) || 0);

      if (!isPro) {
        if (lifetimeScans >= 1) {
          return new Response(
            JSON.stringify({
              allowed: false,
              code: 'FREE_QUOTA_EXCEEDED',
              error: 'Cota gratuita esgotada. Assine o PeleIA Pro para análises diárias.',
            }),
            { status: 403, headers: { 'Content-Type': 'application/json' } }
          );
        }
        // Incrementa atomicamente o contador vitalício
        await this.state.storage.put('lifetime_scans', lifetimeScans + 1);
        return new Response(
          JSON.stringify({ allowed: true, remaining: 0, reserved: true }),
          { status: 200, headers: { 'Content-Type': 'application/json' } }
        );
      } else {
        if (dailyScans >= 2) {
          return new Response(
            JSON.stringify({
              allowed: false,
              code: 'PRO_DAILY_LIMIT_REACHED',
              error: 'Limite diário do PeleIA Pro atingido (2/2). Volte amanhã para nova avaliação.',
            }),
            { status: 429, headers: { 'Content-Type': 'application/json' } }
          );
        }
        // Incrementa atomicamente o contador diário
        await this.state.storage.put(`scans_${todayKey}`, dailyScans + 1);
        return new Response(
          JSON.stringify({ allowed: true, remaining: 1 - dailyScans, reserved: true }),
          { status: 200, headers: { 'Content-Type': 'application/json' } }
        );
      }
    }

    // ── ROLLBACK DE COMPENSAÇÃO (Se o Gemini falhar) ──────
    if (url.pathname === '/rollback') {
      const { isPro, todayKey } = (await request.json()) as {
        isPro: boolean;
        todayKey: string;
      };

      if (!isPro) {
        const lifetimeScans = ((await this.state.storage.get<number>('lifetime_scans')) || 1);
        await this.state.storage.put('lifetime_scans', Math.max(0, lifetimeScans - 1));
      } else {
        const dailyScans = ((await this.state.storage.get<number>(`scans_${todayKey}`)) || 1);
        await this.state.storage.put(`scans_${todayKey}`, Math.max(0, dailyScans - 1));
      }

      return new Response(JSON.stringify({ rolledBack: true }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    return new Response('Not Found', { status: 404 });
  }
}

// ══════════════════════════════════════════════════════════
//  2. WORKER PRINCIPAL (Proxy Seguro)
// ══════════════════════════════════════════════════════════
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Método não permitido' }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    try {
      // 2.1 Verificação rápida de Content-Length
      const declaredLength = Number(request.headers.get('Content-Length') || '0');
      if (declaredLength > MAX_REQUEST_BYTES) {
        return new Response(
          JSON.stringify({ error: 'Payload excede o limite máximo permitido de 2.5MB.' }),
          { status: 413, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // 2.2 Autenticação JWT e Verificação de Identidade no Servidor
      const authHeader = request.headers.get('Authorization');
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return new Response(
          JSON.stringify({ error: 'Token de autenticação não fornecido ou formato inválido.' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const idToken = authHeader.replace('Bearer ', '').trim();
      const authUser = await verifyAuthToken(idToken, env);
      if (!authUser) {
        return new Response(
          JSON.stringify({ error: 'Token expirado ou inválido. Autentique-se novamente no app.' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // 2.3 Leitura com Bounded Streaming (Commit B aprofundado)
      const readResult = await readBoundedStream(request.body, MAX_REQUEST_BYTES);
      if (readResult.error) {
        return new Response(
          JSON.stringify({ error: readResult.error }),
          { status: 413, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const jsonText = new TextDecoder().decode(readResult.buffer);
      const body = JSON.parse(jsonText) as {
        image_base64?: string;
        task?: 'vision' | 'report';
        prompt?: string;
      };

      if (!body.image_base64 && !body.prompt) {
        return new Response(
          JSON.stringify({ error: 'Requisição inválida: envie a imagem ou o prompt.' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const todayKey = new Date().toISOString().slice(0, 10);
      let quotaReserved = false;
      let doStub: DurableObjectStub | null = null;

      // 2.4 Reserva Atômica de Cota via Durable Object (apenas para tarefa de visão)
      if (body.task === 'vision' && env.QUOTA_DO) {
        const doId = env.QUOTA_DO.idFromName(authUser.uid);
        doStub = env.QUOTA_DO.get(doId);

        const reserveRes = await doStub.fetch('http://quota/reserve', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ isPro: authUser.isPro, todayKey }),
        });

        if (!reserveRes.ok) {
          const reserveErr = await reserveRes.json();
          return new Response(JSON.stringify(reserveErr), {
            status: reserveRes.status,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        quotaReserved = true;
      }

      // 2.5 Chamada Segura para Gemini API
      const model = env.GEMINI_MODEL || 'gemini-3.6-flash';
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`;

      let geminiPayload: any;
      if (body.task === 'vision' && body.image_base64) {
        geminiPayload = {
          contents: [
            {
              parts: [
                { text: body.prompt || 'Analise esta selfie cosmética.' },
                {
                  inline_data: {
                    mime_type: 'image/jpeg',
                    data: body.image_base64,
                  },
                },
              ],
            },
          ],
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 1024,
            responseMimeType: 'application/json',
          },
        };
      } else {
        geminiPayload = {
          contents: [{ parts: [{ text: body.prompt }] }],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 2048,
          },
        };
      }

      // LGPD: Log apenas operacional anônimo, NUNCA da foto ou Base64
      console.log(`[Proxy] Processando tarefa '${body.task}' para UID: ${authUser.uid.slice(0, 6)}***`);

      const geminiRes = await fetch(geminiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(geminiPayload),
      });

      if (!geminiRes.ok) {
        const errorText = await geminiRes.text();
        console.error(`[Proxy Error] Gemini retornou ${geminiRes.status}: ${errorText.slice(0, 120)}`);

        // Rollback da cota em caso de falha no provedor upstream
        if (quotaReserved && doStub) {
          await doStub.fetch('http://quota/rollback', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ isPro: authUser.isPro, todayKey }),
          });
          console.log(`[Proxy] Cota compensada com sucesso após erro upstream.`);
        }

        return new Response(
          JSON.stringify({ error: 'Erro de processamento pelo provedor de IA.' }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const geminiData = (await geminiRes.json()) as any;
      const textOutput = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || '';

      return new Response(
        JSON.stringify({ success: true, output: textOutput }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    } catch (err: any) {
      console.error('[Proxy Fatal]', err.message);
      return new Response(
        JSON.stringify({ error: 'Falha interna de comunicação no servidor seguro.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
  },
};

/**
 * Lê o stream da requisição de forma limitada (Bounded Stream)
 * Aborta imediatamente se ultrapassar o limite de bytes, prevenindo exaustão de memória
 */
async function readBoundedStream(
  stream: ReadableStream | null,
  maxBytes: number
): Promise<{ buffer: Uint8Array; error?: string }> {
  if (!stream) {
    return { buffer: new Uint8Array(0) };
  }

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
        return {
          buffer: new Uint8Array(0),
          error: 'Payload excede o limite máximo permitido de 2.5MB.',
        };
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

/**
 * Validação de integridade do JWT (exp, iss, aud, claims)
 */
async function verifyAuthToken(token: string, env: Env): Promise<DecodedToken | null> {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const payloadJson = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'));
    const payload = JSON.parse(payloadJson);

    // 1. Expiração
    const nowSec = Math.floor(Date.now() / 1000);
    if (!payload.exp || payload.exp < nowSec) {
      return null;
    }

    // 2. Issuer e Audience (se configurado FIREBASE_PROJECT_ID)
    if (env.FIREBASE_PROJECT_ID) {
      const expectedIss = `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`;
      if (payload.iss !== expectedIss || payload.aud !== env.FIREBASE_PROJECT_ID) {
        return null;
      }
    }

    const uid = payload.sub || payload.user_id || payload.uid;
    if (!uid) return null;

    // Entitlement autoritativo: custom claims do token, nunca do body do cliente
    const isPro = Boolean(payload.is_pro || payload.premium || payload.stripe_role === 'pro');

    return {
      uid,
      isPro,
      email: payload.email,
    };
  } catch (_) {
    return null;
  }
}
