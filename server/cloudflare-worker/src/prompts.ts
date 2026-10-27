import type { PeleiaConfig } from './config';

export const MAX_NOTE_CHARS = 280;
export const MAX_COMPARISON_CHARS = 800;

const AGE_DESCRIPTIONS: Record<string, string> = {
  under_20: '< 20 anos (Jovem / Adolescente)',
  '20_35': '20 a 35 anos (Jovem adulto / Equilíbrio e prevenção)',
  '36_50': '36 a 50 anos (Maturidade inicial / Prevenção de manchas e firmeza)',
  '50_plus': 'Mais de 50 anos (Pele madura / Hidratação profunda e barreira)',
};

const OUTDOOR_DESCRIPTIONS: Record<string, string> = {
  outdoor_high: 'Alta exposição solar (pratica esportes ao ar livre, praia ou exposição diária frequente)',
  outdoor_moderate: 'Exposição solar moderada (finais de semana, trajetos e lazer)',
  outdoor_low: 'Baixa exposição solar (ambiente fechado, escritório / home office preponderante)',
};

const SKIN_TYPES = ['oleosa', 'seca', 'mista', 'normal', 'sensivel'];
const SKIN_TONES = ['muito_clara', 'clara', 'media', 'morena', 'morena_escura', 'negra'];
const SUN_URGENCY = ['alta', 'media', 'baixa'];
const KNOWN_PROBLEMS = [
  'acne_ativa', 'cravos', 'manchas_solares', 'melasma', 'poros_dilatados',
  'oleosidade_excessiva', 'vermelhidao', 'ressecamento', 'olheiras',
];
const SCORE_KEYS = [
  'oleosidade', 'acne_cravos', 'manchas_solares', 'sensibilidade', 'hidratacao', 'poros_dilatados',
];

export interface SanitizedProfile {
  ageDescription: string;
  outdoorDescription: string;
  declaredSkinType: string;
  avoidLabels: string[];
  conditionLabels: string[];
  note: string;
}

/** Remove delimitadores e marcadores de template para que o texto do usuário não vire instrução. */
export function sanitizeUserText(value: unknown, maxChars: number): string {
  if (typeof value !== 'string') return '';
  return value
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/<<<|>>>|\{\{|\}\}|```/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxChars);
}

function stringList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((v): v is string => typeof v === 'string') : [];
}

export function sanitizeProfile(input: unknown, config: PeleiaConfig): SanitizedProfile {
  const profile = (input && typeof input === 'object' ? input : {}) as Record<string, unknown>;
  const { ingredients, conditions } = config.profile_options;

  const conditionIds = new Set(stringList(profile.conditions));
  const selectedConditions = conditions.filter((c) => conditionIds.has(c.id));

  const avoidIds = new Set(stringList(profile.avoid_ingredients));
  for (const condition of selectedConditions) condition.excludes.forEach((id) => avoidIds.add(id));

  const declared = typeof profile.declared_skin_type === 'string' ? profile.declared_skin_type : '';

  return {
    ageDescription:
      AGE_DESCRIPTIONS[profile.age_group as string] ?? 'Não informada (faixa padrão 20-35 anos)',
    outdoorDescription:
      OUTDOOR_DESCRIPTIONS[profile.outdoor_exposure as string] ?? 'Moderada (padrão rotina mista brasileira)',
    declaredSkinType: SKIN_TYPES.includes(declared) ? declared : 'não informado',
    avoidLabels: ingredients.filter((i) => avoidIds.has(i.id)).map((i) => i.label),
    conditionLabels: selectedConditions.map((c) => c.label),
    note: sanitizeUserText(profile.note, MAX_NOTE_CHARS),
  };
}

/** Substituição em passada única: valores inseridos nunca são reprocessados como template. */
export function fillTemplate(template: string, vars: Record<string, string>): string {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key: string) => vars[key] ?? '');
}

export function buildVisionPrompt(config: PeleiaConfig, profile: SanitizedProfile): string {
  return fillTemplate(config.server.vision_prompt, {
    age: profile.ageDescription,
    outdoor: profile.outdoorDescription,
    declared_skin_type: profile.declaredSkinType,
  });
}

export function buildReportPrompt(
  config: PeleiaConfig,
  profile: SanitizedProfile,
  analysis: NormalizedAnalysis,
  comparisonSummary: unknown,
): string {
  const summary = sanitizeUserText(comparisonSummary, MAX_COMPARISON_CHARS);
  const server = config.server;

  const hasRestrictions =
    profile.avoidLabels.length > 0 || profile.conditionLabels.length > 0 || profile.note.length > 0;

  const restrictions = hasRestrictions
    ? fillTemplate(server.report_restrictions, {
        avoid_list: profile.avoidLabels.join(', ') || 'nenhum',
        conditions: profile.conditionLabels.join(', ') || 'nenhuma',
        user_note: profile.note || '(sem observação)',
      })
    : '';

  return fillTemplate(server.report_prompt, {
    age: profile.ageDescription,
    outdoor: profile.outdoorDescription,
    declared_skin_type: profile.declaredSkinType,
    restrictions_section: restrictions,
    analysis_json: JSON.stringify(analysis),
    memory_section: summary
      ? fillTemplate(server.report_memory_section, { comparison_summary: summary })
      : '',
    memory_header: summary
      ? server.report_memory_followup
      : fillTemplate(server.report_memory_first, { score_geral: String(analysis.score_geral) }),
  });
}

export interface NormalizedAnalysis {
  skin_type: string;
  tom_de_pele: string;
  scores: Record<string, number>;
  problemas_detectados: string[];
  urgencia_protetor_solar: string;
  score_geral: number;
  confianca: number;
  observacao_clima: string;
}

function clampInt(value: unknown, min: number, max: number, fallback: number): number {
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.round(n)));
}

function pick(value: unknown, allowed: string[], fallback: string): string {
  return typeof value === 'string' && allowed.includes(value) ? value : fallback;
}

/** Normaliza a saída do modelo para o formato e intervalos que o app espera. */
export function normalizeAnalysis(raw: any): NormalizedAnalysis {
  const rawScores = raw?.scores && typeof raw.scores === 'object' ? raw.scores : {};
  const scores: Record<string, number> = {};
  for (const key of SCORE_KEYS) scores[key] = clampInt(rawScores[key], 0, 10, 5);

  const confidence = Number(raw?.confianca);
  return {
    skin_type: pick(raw?.skin_type, SKIN_TYPES, 'mista'),
    tom_de_pele: pick(raw?.tom_de_pele, SKIN_TONES, 'media'),
    scores,
    problemas_detectados: stringList(raw?.problemas_detectados).filter((p) => KNOWN_PROBLEMS.includes(p)),
    urgencia_protetor_solar: pick(raw?.urgencia_protetor_solar, SUN_URGENCY, 'alta'),
    score_geral: clampInt(raw?.score_geral, 0, 100, 70),
    confianca: Number.isFinite(confidence) ? Math.min(1, Math.max(0, confidence)) : 0.5,
    observacao_clima: sanitizeUserText(raw?.observacao_clima, 300),
  };
}

/** Extrai o JSON da resposta do modelo, tolerando cercas de markdown e texto extra. */
export function parseModelJson(text: string): any {
  const cleaned = text.replace(/```json/gi, '').replace(/```/g, '').trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const firstBrace = cleaned.indexOf('{');
    const lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
      return JSON.parse(cleaned.slice(firstBrace, lastBrace + 1));
    }
    throw new Error('Formato JSON inválido retornado pelo modelo');
  }
}
