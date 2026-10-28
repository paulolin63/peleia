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

let cached: { at: number; key: string; config: PeleiaConfig } | null = null;

export const CLOSED_TESTING_FREE_LIFETIME = 20;
export const PRODUCTION_FREE_LIFETIME = 1;

/** JSON holds production quotas; ENVIRONMENT boosts free scans for Play closed testing. */
export function withEnvQuota(config: PeleiaConfig, environment?: string): PeleiaConfig {
  const mode = (environment || 'production').trim().toLowerCase();
  const free =
    mode === 'closed_testing' || mode === 'development'
      ? CLOSED_TESTING_FREE_LIFETIME
      : PRODUCTION_FREE_LIFETIME;
  if (config.quota.free_lifetime === free) return config;
  return {
    ...config,
    quota: { ...config.quota, free_lifetime: free },
  };
}

export async function loadConfig(
  kv: KVNamespace | undefined,
  environment?: string,
): Promise<PeleiaConfig> {
  const cacheKey = `${environment || 'production'}`;
  if (cached && cached.key === cacheKey && Date.now() - cached.at < CACHE_TTL_MS) {
    return cached.config;
  }

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

  config = withEnvQuota(config, environment);
  cached = { at: Date.now(), key: cacheKey, config };
  return config;
}

export function resetConfigCache(): void {
  cached = null;
}

export function publicConfig(config: PeleiaConfig): Record<string, unknown> {
  const { server: _server, ...rest } = config;
  return rest;
}
