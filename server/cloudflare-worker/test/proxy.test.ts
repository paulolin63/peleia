/**
 * PeleIA - Suíte de Testes de Integração e Concorrência do Worker Proxy
 * 
 * Validações de Produção:
 * 1. Autenticação e Rejeição de JWT inválido/expirado
 * 2. Limite Bounded de Payload (2.5MB) e rejeição imediata
 * 3. Atomicidade Concorrente do QuotaDurableObject (Zero Race Condition)
 * 4. Mecanismo de Rollback após falha upstream do Gemini
 */

import { describe, it, expect, beforeEach } from 'vitest';
import worker, { QuotaDurableObject, Env } from '../src/index';

// Mock de MockStorage para o DurableObject
class MockDurableObjectStorage {
  private data = new Map<string, any>();

  async get<T>(key: string): Promise<T | undefined> {
    return this.data.get(key);
  }

  async put(key: string, value: any): Promise<void> {
    this.data.set(key, value);
  }

  async delete(key: string): Promise<boolean> {
    return this.data.delete(key);
  }
}

class MockDurableObjectState {
  storage = new MockDurableObjectStorage() as any;
}

describe('PeleIA Gemini Proxy - Validação de Segurança e Concorrência', () => {
  let quotaDO: QuotaDurableObject;
  const mockState = new MockDurableObjectState();

  beforeEach(() => {
    quotaDO = new QuotaDurableObject(mockState as any);
  });

  // ── 1. Atomicidade de Cotas em Concorrência (P0) ──────────
  it('Deve permitir EXATAMENTE 1 requisição em 5 chamadas concorrentes para usuário Free', async () => {
    const todayKey = '2026-10-21';

    // Dispara 5 requisições atômicas simultâneas via Promise.all
    const promises = Array.from({ length: 5 }).map(() =>
      quotaDO.fetch(
        new Request('http://quota/reserve', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ isPro: false, todayKey }),
        })
      )
    );

    const responses = await Promise.all(promises);
    const statuses = responses.map((r) => r.status);

    // Exatamente uma requisição deve ser 200 (autorizada)
    const allowedCount = statuses.filter((s) => s === 200).length;
    // As outras quatro devem ser 403 (bloqueadas por cota)
    const blockedCount = statuses.filter((s) => s === 403).length;

    expect(allowedCount).toBe(1);
    expect(blockedCount).toBe(4);
  });

  it('Deve limitar estritamente o Pro a 2 análises por dia com rollback em erro', async () => {
    const todayKey = '2026-10-21';

    // 1ª análise Pro: OK
    const res1 = await quotaDO.fetch(
      new Request('http://quota/reserve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isPro: true, todayKey }),
      })
    );
    expect(res1.status).toBe(200);

    // 2ª análise Pro: OK
    const res2 = await quotaDO.fetch(
      new Request('http://quota/reserve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isPro: true, todayKey }),
      })
    );
    expect(res2.status).toBe(200);

    // 3ª análise Pro: 429 Too Many Requests
    const res3 = await quotaDO.fetch(
      new Request('http://quota/reserve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isPro: true, todayKey }),
      })
    );
    expect(res3.status).toBe(429);

    // Simula falha no Gemini na 2ª análise e executa Rollback
    const rollbackRes = await quotaDO.fetch(
      new Request('http://quota/rollback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isPro: true, todayKey }),
      })
    );
    expect(rollbackRes.status).toBe(200);

    // Após o rollback, uma nova tentativa deve voltar a ser permitida
    const retryRes = await quotaDO.fetch(
      new Request('http://quota/reserve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isPro: true, todayKey }),
      })
    );
    expect(retryRes.status).toBe(200);
  });

  // ── 2. Autenticação e Rejeição de Tokens ──────────────────
  it('Deve rejeitar requisições sem Authorization Bearer Token com HTTP 401', async () => {
    const env: Env = {
      GEMINI_API_KEY: 'test_key',
      QUOTA_DO: {} as any,
    };

    const req = new Request('http://worker/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ task: 'report', prompt: 'teste' }),
    });

    const res = await worker.fetch(req, env);
    expect(res.status).toBe(401);
    const body = (await res.json()) as any;
    expect(body.error).toContain('Token de autenticação não fornecido');
  });

  // ── 3. Proteção Bounded contra Exaustão de Memória ────────
  it('Deve rejeitar prematuramente requisições com Content-Length superior a 2.5MB', async () => {
    const env: Env = {
      GEMINI_API_KEY: 'test_key',
      QUOTA_DO: {} as any,
    };

    const req = new Request('http://worker/', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer token_valido_com_mais_de_vinte_caracteres',
        'Content-Length': '3500000', // 3.5MB anunciado
      },
      body: JSON.stringify({ task: 'vision', image_base64: 'fake' }),
    });

    const res = await worker.fetch(req, env);
    expect(res.status).toBe(413);
    const body = (await res.json()) as any;
    expect(body.error).toContain('Payload excede o limite');
  });
});
