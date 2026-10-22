import bundledConfig from '../../config/peleia_config.json';

export interface QuotaLimits {
  free_lifetime: number;
  pro_daily: number;
  sos_credits: number;
}

export interface PlanConfig {
  product_id: string;
  consumable: boolean;
}

export interface ProfileIngredientOption {
  id: string;
  label: string;
  keywords?: string[];
}

export interface ProfileConditionOption {
  id: string;
  label: string;
  excludes: string[];
}

export interface ServerConfig {
  model: string;
  vision_prompt: string;
  report_prompt: string;
  report_memory_first: string;
  report_memory_followup: string;
  report_memory_section: string;
  report_restrictions: string;
}

export interface PeleiaConfig {
  schema_version: number;
  config_version: string;
  min_app_build: number;
  quota: QuotaLimits;
  plans: PlanConfig[];
  profile_options: {
    ingredients: ProfileIngredientOption[];
    conditions: ProfileConditionOption[];
  };
  server: ServerConfig;
  [key: string]: unknown;
}

export const CONFIG_KV_KEY = 'peleia_config';
export const SUPPORTED_SCHEMA_VERSION = 1;
const CACHE_TTL_MS = 60_000;

let cached: { at: number; config: PeleiaConfig } | null = null;

export async function loadConfig(kv: KVNamespace | undefined): Promise<PeleiaConfig> {
  if (cached && Date.now() - cached.at < CACHE_TTL_MS) return cached.config;

  let config = bundledConfig as unknown as PeleiaConfig;
  if (kv) {
    const raw = await kv.get(CONFIG_KV_KEY);
    if (raw) {
      try {
        const parsed = JSON.parse(raw) as PeleiaConfig;
        if (parsed.schema_version === SUPPORTED_SCHEMA_VERSION && parsed.server && parsed.quota) {
          config = parsed;
        } else {
          console.error('[Config] KV com schema desconhecido; usando config embutida.');
        }
      } catch {
        console.error('[Config] KV com JSON inválido; usando config embutida.');
      }
    }
  }

  cached = { at: Date.now(), config };
  return config;
}

export function resetConfigCache(): void {
  cached = null;
}

export function publicConfig(config: PeleiaConfig): Record<string, unknown> {
  const { server: _server, ...rest } = config;
  return rest;
}
