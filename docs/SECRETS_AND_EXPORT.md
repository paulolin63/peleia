# Secrets, keystore e export limpo

## Nunca colocar no zip / git

| Arquivo | Motivo |
|---------|--------|
| `peleia-release.jks` / `*.jks` | Assinatura Play — quem tem o arquivo + senha publica como você |
| `android/key.properties` | Senhas do keystore |
| `.env` | Keys locais; **não** listar em `pubspec.yaml` assets |
| `.dev.vars` | Secrets do Worker local |
| `server/cloudflare-worker/.wrangler/` | Estado Miniflare / KV local |
| `android/local.properties` | Paths da máquina |
| `android/build/`, `build/` | Artefatos |
| `android/app/google-services.json` | Preferir baixar do Firebase Console (já no `.gitignore`) |

Templates ok: `.env.example`, `android/key.properties.example`, `server/cloudflare-worker/.dev.vars.example`.

## Export limpo

```bash
./scripts/export_source.sh
# → dist/peleia-source-clean.zip
```

## Se um zip com keystore já vazou

1. No Play Console: App signing → request upload key reset (ou gerar novo upload key e registrar).
2. Gere novo keystore (`scripts/generate_keystore.sh`), novo `key.properties` fora do repo.
3. Rotacione: Gemini API key (Google AI Studio), RevenueCat secret (Worker), Firebase API key restrictions (GCP).
4. Redeploy Worker com `wrangler secret put GEMINI_API_KEY` / `REVENUECAT_SECRET_KEY`.

## Build sem embutir `.env`

```bash
flutter build appbundle --release \
  --dart-define=PELEIA_ENV=closed_testing \
  --dart-define=GEMINI_PROXY_URL=https://YOUR_WORKER.workers.dev \
  --dart-define=REVENUECAT_ANDROID_KEY=rc_public_android_key
```

Release efetivo: omita `PELEIA_ENV` (default release = `production`) ou force `PELEIA_ENV=production`. Worker: `ENVIRONMENT=production`.
