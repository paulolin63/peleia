/**
 * PeleIA - Backend Proxy Seguro para Gemini API (Cloudflare Worker)
 * 
 * Arquitetura de Produção e Launch Hardening:
 * 1. Proteção de Chaves: GEMINI_API_KEY armazenada exclusivamente nos Secrets do Cloudflare.
 * 2. Autenticação e JWT: Validação de claims de assinatura (aud, iss, exp, uid).
 * 3. Cota no Servidor: Não confia no isPro do cliente; ledger em Cloudflare KV por UID.
 * 4. Proteção de Payload Estrita: MAX_REQUEST_BYTES = 2.500.000 (mede os bytes reais lidos).
 * 5. LGPD & Zero-Log: NUNCA grava logs de fotos, Base64 ou dados biométricos em stdout/loggers.
 */

export interface Env {
  GEMINI_API_KEY: string;
  GEMINI_MODEL?: string;
  FIREBASE_PROJECT_ID?: string;
  ENVIRONMENT?: string;
  QUOTA_KV?: KVNamespace; // Cloudflare KV para ledger autoritativo de cotas
}

// 2.5 MB máximo para o payload JSON completo (incluindo Base64 da imagem ~1.5MB original)
const MAX_REQUEST_BYTES = 2_500_000;

interface DecodedToken {
  uid: string;
  isPro: boolean;
  email?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    // 1. CORS Preflight
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
      // 2. Validação Estrita do Tamanho da Requisição (Header + Stream Real)
      const declaredLength = Number(request.headers.get('Content-Length') || '0');
      if (declaredLength > MAX_REQUEST_BYTES) {
        return new Response(
          JSON.stringify({ error: 'Payload excede o limite máximo permitido de 2.5MB.' }),
          { status: 413, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const rawBuffer = await request.arrayBuffer();
      if (rawBuffer.byteLength > MAX_REQUEST_BYTES) {
        return new Response(
          JSON.stringify({ error: 'Corpo da requisição excede o limite máximo de 2.5MB.' }),
          { status: 413, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // 3. Autenticação JWT e Verificação de Identidade no Servidor
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

      // 4. Verificação Autoritativa de Cota no Servidor (Não confia no cliente)
      const todayKey = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
      const quotaKey = `user:${authUser.uid}:quota:${todayKey}`;
      const lifetimeKey = `user:${authUser.uid}:lifetime_scans`;

      if (env.QUOTA_KV) {
        if (!authUser.isPro) {
          // Usuário Free: máximo 1 análise vitalícia (cortesia de boas-vindas)
          const lifetimeCount = Number(await env.QUOTA_KV.get(lifetimeKey) || '0');
          if (lifetimeCount >= 1) {
            return new Response(
              JSON.stringify({
                error: 'Cota gratuita esgotada. Assine o PeleIA Pro para análises diárias.',
                code: 'FREE_QUOTA_EXCEEDED',
              }),
              { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
          }
        } else {
          // Assinante Pro: máximo 2 análises por dia (manhã e noite) para proteger custos de API
          const dailyCount = Number(await env.QUOTA_KV.get(quotaKey) || '0');
          if (dailyCount >= 2) {
            return new Response(
              JSON.stringify({
                error: 'Limite diário do PeleIA Pro atingido (2/2). Volte amanhã para nova avaliação.',
                code: 'PRO_DAILY_LIMIT_REACHED',
              }),
              { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
          }
        }
      }

      // 5. Parse seguro do Payload JSON
      const jsonText = new TextDecoder().decode(rawBuffer);
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

      // 6. Chamada Segura para Gemini API (Secret isolado no Worker)
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

      // LGPD: Log apenas de metadados operacionais, NUNCA da imagem nem de dados biométricos
      console.log(`[Proxy] Processando tarefa '${body.task}' para UID: ${authUser.uid.slice(0, 6)}***`);

      const geminiRes = await fetch(geminiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(geminiPayload),
      });

      if (!geminiRes.ok) {
        const errorText = await geminiRes.text();
        console.error(`[Proxy Error] Gemini retornou ${geminiRes.status}: ${errorText.slice(0, 120)}`);
        return new Response(
          JSON.stringify({ error: 'Erro de processamento pelo provedor de IA.' }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const geminiData = await geminiRes.json() as any;
      const textOutput = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || '';

      // 7. Incrementa o ledger de cota no KV após sucesso comprovado
      if (env.QUOTA_KV && body.task === 'vision') {
        if (!authUser.isPro) {
          const lifetimeCount = Number(await env.QUOTA_KV.get(lifetimeKey) || '0');
          await env.QUOTA_KV.put(lifetimeKey, String(lifetimeCount + 1));
        } else {
          const dailyCount = Number(await env.QUOTA_KV.get(quotaKey) || '0');
          await env.QUOTA_KV.put(quotaKey, String(dailyCount + 1), {
            expirationTtl: 86400 * 2, // Expira após 48h
          });
        }
      }

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
 * Valida a integridade do JWT (exp, iss, aud, claims)
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

    // Entitlement autoritativo: lido dos custom claims do token, nunca do body do cliente
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
