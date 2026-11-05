#!/usr/bin/env bash
# Cria zip de source sem secrets nem artefatos locais.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${ROOT}/dist"
STAMP="$(date +%Y%m%d)"
OUT_ZIP="${OUT_DIR}/peleia-source-clean-${STAMP}.zip"

mkdir -p "$OUT_DIR"
rm -f "$OUT_ZIP"

cd "$(dirname "$ROOT")"
zip -r "$OUT_ZIP" "$(basename "$ROOT")" \
  -x "$(basename "$ROOT")/.git/*" \
  -x "$(basename "$ROOT")/.env" \
  -x "$(basename "$ROOT")/*.jks" \
  -x "$(basename "$ROOT")/*.keystore" \
  -x "$(basename "$ROOT")/android/key.properties" \
  -x "$(basename "$ROOT")/android/local.properties" \
  -x "$(basename "$ROOT")/android/app/google-services.json" \
  -x "$(basename "$ROOT")/android/.gradle/*" \
  -x "$(basename "$ROOT")/android/build/*" \
  -x "$(basename "$ROOT")/android/.kotlin/*" \
  -x "$(basename "$ROOT")/build/*" \
  -x "$(basename "$ROOT")/.dart_tool/*" \
  -x "$(basename "$ROOT")/server/cloudflare-worker/.wrangler/*" \
  -x "$(basename "$ROOT")/server/cloudflare-worker/.dev.vars" \
  -x "$(basename "$ROOT")/server/cloudflare-worker/node_modules/*" \
  -x "$(basename "$ROOT")/dist/*" \
  -x "$(basename "$ROOT")/**/__pycache__/*" \
  -x "$(basename "$ROOT")/**/*.pyc" \
  -x "$(basename "$ROOT")/.flutter-plugins-dependencies"

echo "Wrote $OUT_ZIP"
# Fail only on real secret paths (allow *.example and Flutter ephemeral *.env tooling files).
BAD=$(unzip -l "$OUT_ZIP" | awk '{print $4}' | grep -E \
  '(^|/)[^/]+\.jks$|(^|/)key\.properties$|(^|/)\.env$|(^|/)\.wrangler/|(^|/)google-services\.json$' \
  || true)
if [[ -n "$BAD" ]]; then
  echo "ERROR: secrets still in zip:" >&2
  echo "$BAD" >&2
  exit 1
fi
echo "OK: no keystore/.env/key.properties/.wrangler/google-services in zip"
