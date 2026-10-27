#!/bin/bash
# =============================================================
#  scripts/build_apk.sh
#
#  Build do APK de teste/sideload para instalar direto no celular
# =============================================================

set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/development/flutter/bin:$PATH"

echo "📱 Building PeleIA APK para teste no celular..."

flutter build apk --release

echo ""
echo "✅ APK gerado com sucesso em:"
echo "   build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "📲 Como instalar no seu celular:"
echo "   1. Envie o arquivo app-release.apk para seu celular Android (via Google Drive, WhatsApp, cabo USB)"
echo "   2. No celular, toque no arquivo .apk para instalar e testar!"
