# PeleIA

Skincare com IA para o mercado brasileiro (`com.peleia.app`).

Selfie → Cloudflare Worker (Gemini) → scores + rotina PT-BR + produtos afiliados. Free / Pro / SOS via RevenueCat. Auth Firebase (anônimo + Google opcional).

## Stack

| Camada | Tech |
|--------|------|
| App | Flutter (Riverpod, go_router) |
| Proxy IA | Cloudflare Worker + Durable Objects (cota) |
| Config | KV `/config` + asset fallback |
| Billing | RevenueCat + Play Billing |

## Closed testing vs production

| Mode | `PELEIA_ENV` / Worker `ENVIRONMENT` | Free lifetime |
|------|--------------------------------------|---------------|
| Closed testing | `closed_testing` | 20 |
| Launch | `production` (release default) | 1 |

Detalhes: [`docs/GO_LIVE.md`](docs/GO_LIVE.md).

## Setup local

```bash
cp .env.example .env   # preencha GEMINI_PROXY_URL + REVENUECAT (opcional)
# google-services.json → android/app/ (Firebase Console)
# key.properties → android/ (from key.properties.example); .jks fora do git

flutter pub get
flutter run --dart-define-from-file=.env
```

Worker:

```bash
cd server/cloudflare-worker
cp .dev.vars.example .dev.vars
npm install && npm test
npx wrangler dev
```

**Nunca** liste `.env` em `pubspec.yaml` assets — keys iriam no APK.

## Export de source limpo

```bash
./scripts/export_source.sh
```

Ver [`docs/SECRETS_AND_EXPORT.md`](docs/SECRETS_AND_EXPORT.md).

## Testes

```bash
flutter test
cd server/cloudflare-worker && npm test
```

## Docs

- [`docs/GO_LIVE.md`](docs/GO_LIVE.md) — flip closed testing → production
- [`docs/SECRETS_AND_EXPORT.md`](docs/SECRETS_AND_EXPORT.md) — keystore / zip
- [`docs/google_play_submission.md`](docs/google_play_submission.md) — Play Console
