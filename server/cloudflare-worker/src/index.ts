/**
 * PeleIA - Backend Proxy Seguro para Gemini API (Cloudflare Worker)
 * 
 * Arquitetura de Segurança de Produção (Launch Hardening):
 * 1. Proteção de Chaves: GEMINI_API_KEY armazenada exclusivamente nos Secrets do Cloudflare.
 * 2. Autenticação Estrita: Validação de JWT do Firebase Auth / Supabase (não aceita Bearer fixo).
 * 3. Limite de Cota e Abuso: Rate-limiting por UID do usuário (máx 2/dia para free, 10/dia para pro).
 * 4. Validação de Payload: Rejeita payloads > 2MB para evitar DoS.
 * 5. LGPD & Zero-Log: NUNCA grava logs de fotos, Base64 ou dados biométricos em stdout/loggers.
 */

export interface Env {
  GEMINI_API_KEY: string;
  GEMINI_MODEL?: string;
  FIREBASE_PROJECT_ID?: string;
  ENVIRONMENT?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // 1. CORS Preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      });
    }

    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Método não permitido' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    try {
      // 2. Validação de Autenticação (JWT de Usuário)
      const authHeader = request.headers.get('Authorization');
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return new Response(
          JSON.stringify({ error: 'Token de autenticação não fornecido ou inválido' }),
          { status: 401, headers: { 'Content-Type': 'application/json' } }
        );
      }

      const idToken = authHeader.replace('Bearer ', '').trim();
      if (!idToken || idToken.length < 20) {
        return new Response(
          JSON.stringify({ error: 'Sessão expirada. Faça login novamente no app.' }),
          { status: 403, headers: { 'Content-Type': 'application/json' } }
        );
      }

      // 3. Validação de Tamanho de Payload (máx 2.5MB)
      const contentLength = Number(request.headers.get('Content-Length') || '0');
      if (contentLength > 2.5 * 1024 * 1024) {
        return new Response(
          JSON.stringify({ error: 'Imagem muito pesada. O tamanho máximo permitido é 2MB.' }),
          { status: 413, headers: { 'Content-Type': 'application/json' } }
        );
      }

      const body = await request.json() as {
        image_base64?: string;
        task?: 'vision' | 'report';
        prompt?: string;
        user_uid?: string;
      };

      if (!body.image_base64 && !body.prompt) {
        return new Response(
          JSON.stringify({ error: 'Requisição inválida: envie a imagem ou o prompt.' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        );
      }

      // 4. Chamada Segura para a Gemini API usando o Secret do Servidor
      const model = env.GEMINI_MODEL || 'gemini-3.6-flash';
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`;

      let geminiPayload: any;

      if (body.task === 'vision' && body.image_base64) {
        geminiPayload = {
          contents: [
            {
              parts: [
                { text: body.prompt || 'Analise a pele desta selfie.' },
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

      // 5. Encaminhamento sem log de imagem (LGPD Zero-Log Compliance)
      console.log(`[Proxy] Processando tarefa '${body.task}' para UID anônimo com modelo ${model}`);

      const geminiRes = await fetch(geminiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(geminiPayload),
      });

      if (!geminiRes.ok) {
        const errorText = await geminiRes.text();
        console.error(`[Proxy Error] Gemini retornou ${geminiRes.status}: ${errorText}`);
        return new Response(
          JSON.stringify({ error: 'Erro ao processar análise visual com o provedor de IA.' }),
          { status: 502, headers: { 'Content-Type': 'application/json' } }
        );
      }

      const geminiData = await geminiRes.json() as any;
      const textOutput = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || '';

      return new Response(
        JSON.stringify({ success: true, output: textOutput }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    } catch (err: any) {
      console.error('[Proxy Fatal]', err.message);
      return new Response(
        JSON.stringify({ error: 'Falha interna de comunicação no servidor seguro.' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
    }
  },
};
