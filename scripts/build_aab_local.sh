#!/usr/bin/env bash
# Build AAB local (closed testing). Equivalente pratico do: eas build --local
# Uso: ./scripts/with-java17.sh ./scripts/build_aab_local.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .dart_defines.env ]]; then
  echo "Falta .dart_defines.env (PELEIA_ENV, GEMINI_PROXY_URL, REVENUECAT_ANDROID_KEY)" >&2
  exit 1
fi
if [[ ! -f android/key.properties ]] || [[ ! -f peleia-release.jks ]]; then
  echo "Falta keystore / android/key.properties" >&2
  exit 1
fi

VER=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
CODE="${VER##*+}"
NAME="${VER%%+*}"

cat > android/local.properties <<EOF
flutter.sdk=/home/paulo/flutter-sdk
sdk.dir=${ANDROID_HOME:-$HOME/Android/Sdk}
flutter.buildMode=release
flutter.versionName=$NAME
flutter.versionCode=$CODE
EOF

echo "=== flutter build appbundle $VER ==="
flutter build appbundle --release --dart-define-from-file=.dart_defines.env

mkdir -p dist
OUT="dist/peleia-${VER}-closed_testing.aab"
cp -f build/app/outputs/bundle/release/app-release.aab "$OUT"
ls -lah "$OUT"
echo "OK: $OUT"
