#!/bin/bash
# =============================================================
#  scripts/build_release.sh
#
#  Build do APK/AAB de release para enviar ao Google Play
# =============================================================

set -e

echo "🔨 Building PeleIA release..."

# Limpa build anterior
flutter clean

# Instala dependências
flutter pub get

# Build AAB (Android App Bundle — formato exigido pelo Google Play)
flutter build appbundle \
  --release \
  --dart-define=GEMINI_API_KEY=${GEMINI_API_KEY:-""}

echo ""
echo "✅ AAB gerado em: build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "📤 Próximo passo: enviar para o Google Play Console"
echo "   Play Console → Testes → Teste interno → Criar versão → Upload AAB"
