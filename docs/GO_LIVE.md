# Go-live (sair do closed testing → production)

Closed testing usa `ENVIRONMENT=closed_testing` / `PELEIA_ENV=closed_testing` → **20** free lifetime.
Build efetivo usa **production** → **1** free. O código já faz o flip; falta só config no deploy.

## Worker (Cloudflare)

1. Em [`server/cloudflare-worker/wrangler.toml`](../server/cloudflare-worker/wrangler.toml):
   - `ENVIRONMENT = "production"`
2. Secrets (nunca no git):
   ```bash
   cd server/cloudflare-worker
   wrangler secret put GEMINI_API_KEY
   wrangler secret put REVENUECAT_SECRET_KEY
   ```
3. Confirme `FIREBASE_PROJECT_ID`, `PREMIUM_ENTITLEMENT_ID`, `ALLOWED_ORIGINS`.
4. `wrangler deploy`
5. Smoke: `GET https://YOUR_WORKER/config` → `quota.free_lifetime === 1`.

## App (Flutter release)

1. **Não** passe `PELEIA_ENV=closed_testing` no release.
   - Default em `kReleaseMode` já é `production` ([`lib/core/config/peleia_env.dart`](../lib/core/config/peleia_env.dart)).
2. Proxy-only — sem `GEMINI_API_KEY` no client:
   ```bash
   flutter build appbundle --release \
     --dart-define=GEMINI_PROXY_URL=https://YOUR_WORKER.workers.dev \
     --dart-define=REVENUECAT_ANDROID_KEY=rc_public_android_key
   ```
3. Release build **bloqueia** Gemini direto se o proxy estiver vazio ([`gemini_skin_service.dart`](../lib/core/services/gemini_skin_service.dart)).
4. Keystore só em máquina/CI segura — ver [`SECRETS_AND_EXPORT.md`](SECRETS_AND_EXPORT.md).

## Play Console / copy

- [ ] Remover menção a “20 análises de teste” / closed testing na ficha se ainda existir
- [ ] Alinhar trial: descrição e screenshots (sem “3 dias grátis” se não houver trial)
- [ ] Privacy URL pública ok
- [ ] RevenueCat produtos + entitlement `premium` alinhados ao Worker

## Pós-deploy rápido

| Check | Esperado |
|-------|----------|
| `/config` quota | `free_lifetime: 1` |
| App release sem proxy | Erro claro, sem chamar Google |
| Free user sem `X-Device-Id` | `400 DEVICE_ID_REQUIRED` |
| 2ª análise free mesmo UID | `403` cota |
| Mesmo device, nova conta anônima | `403 DEVICE_QUOTA_EXCEEDED` |
