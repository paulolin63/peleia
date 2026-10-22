import type { PeleiaConfig } from './config';

export interface Entitlements {
  isPro: boolean;
  sosPurchased: number;
}

export class EntitlementLookupError extends Error {}

/** Consulta o RevenueCat (fonte autoritativa de assinatura e compras avulsas). */
export async function fetchEntitlements(
  uid: string,
  secretKey: string | undefined,
  entitlementId: string,
  config: PeleiaConfig,
): Promise<Entitlements> {
  if (!secretKey) return { isPro: false, sosPurchased: 0 };

  const res = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
    { headers: { Authorization: `Bearer ${secretKey}` } },
  );
  if (!res.ok) throw new EntitlementLookupError(`RevenueCat ${res.status}`);

  const data = (await res.json()) as any;
  const subscriber = data?.subscriber ?? {};

  const entitlement = subscriber.entitlements?.[entitlementId];
  const isPro = Boolean(
    entitlement &&
      (entitlement.expires_date == null || Date.parse(entitlement.expires_date) > Date.now()),
  );

  const sosProductIds = config.plans.filter((p) => p.consumable).map((p) => p.product_id);
  const sosPurchases = sosProductIds.reduce(
    (sum, id) => sum + (subscriber.non_subscriptions?.[id]?.length ?? 0),
    0,
  );

  return { isPro, sosPurchased: sosPurchases * config.quota.sos_credits };
}
