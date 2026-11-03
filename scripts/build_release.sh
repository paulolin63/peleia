#!/bin/bash
# =============================================================
#  scripts/build_release.sh
#
#  Build do APK/AAB de release para enviar ao Google Play
# =============================================================

set -e

# Adiciona caminhos do Homebrew e do Flutter ao PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/development/flutter/bin:$PATH"
export JAVA_HOME="/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home"

if ! command -v flutter &> /dev/null; then
  echo "❌ Flutter não foi encontrado no PATH!"
  echo "   Caminho padrão esperado: /opt/homebrew/bin/flutter"
  exit 1
fi

echo "🔨 Building PeleIA release..."

# Limpa build anterior
flutter clean

# Instala dependências
flutter pub get

# Build AAB (Android App Bundle — formato exigido pelo Google Play)
flutter build appbundle \
  --release \
  --android-skip-build-dependency-validation \
  --dart-define=PELEIA_ENV=closed_testing

# Build APK (para teste direto no celular se desejar)
flutter build apk \
  --release \
  --android-skip-build-dependency-validation \
  --dart-define=PELEIA_ENV=closed_testing

# Copia para /Users/paulolin/Projects para fácil upload no Play Console
mkdir -p /Users/paulolin/Projects
cp build/app/outputs/bundle/release/app-release.aab /Users/paulolin/Projects/peleia.aab
cp build/app/outputs/flutter-apk/app-release.apk /Users/paulolin/Projects/peleia.apk

echo ""
echo "✅ AAB gerado com sucesso em:"
echo "   1. build/app/outputs/bundle/release/app-release.aab"
echo "   2. /Users/paulolin/Projects/peleia.aab (Pronto para upload no Play Console)"
echo ""
echo "✅ APK de teste gerado em:"
echo "   1. build/app/outputs/flutter-apk/app-release.apk"
echo "   2. /Users/paulolin/Projects/peleia.apk"
echo ""
echo "📤 Próximo passo: enviar para o Google Play Console"
echo "   Play Console → Testes → Teste fechado (Closed testing) → Criar nova versão → Upload /Users/paulolin/Projects/peleia.aab"
