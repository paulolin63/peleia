// Durable Object de cota: um por usuário. Todas as operações passam por uma fila
// exclusiva, então leitura e escrita de contadores nunca se intercalam.

import type { QuotaLimits } from './config';

export type QuotaKind = 'free' | 'pro' | 'sos';

interface Reservation {
  kind: QuotaKind;
  day: string;
  createdAt: number;
  analysis?: unknown;
  reportAttempts: number;
  reportDone: boolean;
}

type Reservations = Record<string, Reservation>;

const FREE_KEY = 'lifetime_scans';
const SOS_KEY = 'sos_used';
const RESERVATIONS_KEY = 'reservations';
const proKey = (day: string) => `scans_${day}`;

export const ANALYSIS_TTL_MS = 30 * 60 * 1000;
export const MAX_REPORT_ATTEMPTS = 3;

export interface QuotaRequest {
  limits: QuotaLimits;
  isPro: boolean;
  sosPurchased: number;
  day: string;
  analysisId?: string;
  analysis?: unknown;
  now?: number;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

export class QuotaDurableObject {
  state: DurableObjectState;
  private queue: Promise<unknown> = Promise.resolve();

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  private exclusive<T>(fn: () => Promise<T>): Promise<T> {
    const run = this.queue.then(fn, fn);
    this.queue = run.catch(() => undefined);
    return run;
  }

  async fetch(request: Request): Promise<Response> {
    const path = new URL(request.url).pathname;
    const body = (await request.json()) as QuotaRequest;
    return this.exclusive(() => this.handle(path, body));
  }

  private async counters(day: string) {
    const storage = this.state.storage;
    return {
      free: (await storage.get<number>(FREE_KEY)) || 0,
      pro: (await storage.get<number>(proKey(day))) || 0,
      sos: (await storage.get<number>(SOS_KEY)) || 0,
    };
  }

  private status(req: QuotaRequest, c: { free: number; pro: number; sos: number }) {
    return {
      is_pro: req.isPro,
      free_remaining: Math.max(0, req.limits.free_lifetime - c.free),
      pro_remaining_today: req.isPro ? Math.max(0, req.limits.pro_daily - c.pro) : 0,
      sos_remaining: Math.max(0, req.sosPurchased - c.sos),
    };
  }

  private async handle(path: string, req: QuotaRequest): Promise<Response> {
    const storage = this.state.storage;
    const now = req.now ?? Date.now();
    const reservations = ((await storage.get<Reservations>(RESERVATIONS_KEY)) || {}) as Reservations;

    switch (path) {
      case '/status': {
        return json(this.status(req, await this.counters(req.day)));
      }

      case '/reserve': {
        if (!req.analysisId) return json({ error: 'analysisId ausente' }, 400);
        const c = await this.counters(req.day);

        let kind: QuotaKind;
        if (req.isPro) {
          if (c.pro >= req.limits.pro_daily) {
            return json({
              allowed: false,
              code: 'PRO_DAILY_LIMIT_REACHED',
              error: `Limite diário do PeleIA Pro atingido (${req.limits.pro_daily}/${req.limits.pro_daily}). Volte amanhã para nova análise.`,
            }, 429);
          }
          kind = 'pro';
          await storage.put(proKey(req.day), c.pro + 1);
        } else if (c.free < req.limits.free_lifetime) {
          kind = 'free';
          await storage.put(FREE_KEY, c.free + 1);
        } else if (c.sos < req.sosPurchased) {
          kind = 'sos';
          await storage.put(SOS_KEY, c.sos + 1);
        } else {
          return json({
            allowed: false,
            code: req.sosPurchased > 0 ? 'SOS_EMPTY' : 'FREE_QUOTA_EXCEEDED',
            error: req.sosPurchased > 0
              ? 'Seus créditos SOS acabaram. Assine o PeleIA Pro ou compre um novo pacote.'
              : 'Cota gratuita esgotada. Assine o PeleIA Pro para novas análises.',
          }, 403);
        }

        for (const [id, r] of Object.entries(reservations)) {
          if (now - r.createdAt > ANALYSIS_TTL_MS) delete reservations[id];
        }
        reservations[req.analysisId] = {
          kind,
          day: req.day,
          createdAt: now,
          reportAttempts: 0,
          reportDone: false,
        };
        await storage.put(RESERVATIONS_KEY, reservations);

        return json({ allowed: true, kind, ...this.status(req, await this.counters(req.day)) });
      }

      case '/rollback': {
        const r = req.analysisId ? reservations[req.analysisId] : undefined;
        if (!r || r.analysis !== undefined) return json({ rolledBack: false });

        const key = r.kind === 'free' ? FREE_KEY : r.kind === 'sos' ? SOS_KEY : proKey(r.day);
        const current = (await storage.get<number>(key)) || 0;
        await storage.put(key, Math.max(0, current - 1));
        delete reservations[req.analysisId!];
        await storage.put(RESERVATIONS_KEY, reservations);
        return json({ rolledBack: true });
      }

      case '/store': {
        const r = req.analysisId ? reservations[req.analysisId] : undefined;
        if (!r) return json({ error: 'Reserva não encontrada' }, 404);
        r.analysis = req.analysis;
        await storage.put(RESERVATIONS_KEY, reservations);
        return json({ stored: true });
      }

      case '/claim-report': {
        const r = req.analysisId ? reservations[req.analysisId] : undefined;
        if (!r || r.analysis === undefined || now - r.createdAt > ANALYSIS_TTL_MS) {
          return json({ code: 'ANALYSIS_NOT_FOUND', error: 'Análise expirada. Faça uma nova selfie.' }, 404);
        }
        if (r.reportDone || r.reportAttempts >= MAX_REPORT_ATTEMPTS) {
          return json({ code: 'REPORT_ALREADY_GENERATED', error: 'O relatório desta análise já foi gerado.' }, 409);
        }
        r.reportAttempts += 1;
        await storage.put(RESERVATIONS_KEY, reservations);
        return json({ analysis: r.analysis });
      }

      case '/complete-report': {
        const r = req.analysisId ? reservations[req.analysisId] : undefined;
        if (r) {
          r.reportDone = true;
          await storage.put(RESERVATIONS_KEY, reservations);
        }
        return json({ completed: Boolean(r) });
      }

      default:
        return new Response('Not Found', { status: 404 });
    }
  }
}
