#!/bin/bash
# =============================================================
#  scripts/generate_keystore.sh
#
#  Gera o keystore para assinar o APK do PeleIA
#  Execute UMA VEZ e guarde o arquivo .jks em lugar seguro!
# =============================================================

set -e

APP_ID="com.peleia.app"
KEYSTORE_FILE="peleia-release.jks"
KEY_ALIAS="peleia"

echo ""
echo "🔑 Gerando keystore para PeleIA..."
echo "   Guarde as senhas em lugar seguro (ex: 1Password)"
echo ""

# Gera o keystore
keytool -genkey -v \
  -keystore "$KEYSTORE_FILE" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=PeleIA, OU=Mobile, O=PeleIA App, L=São Paulo, ST=SP, C=BR"

echo ""
echo "✅ Keystore gerado: $KEYSTORE_FILE"
echo ""
echo "📝 Agora crie o arquivo android/key.properties com:"
echo ""
echo "storePassword=<SUA_SENHA_DO_KEYSTORE>"
echo "keyPassword=<SUA_SENHA_DA_CHAVE>"
echo "keyAlias=$KEY_ALIAS"
echo "storeFile=../../$KEYSTORE_FILE"
echo ""
echo "⚠️  NUNCA commite key.properties ou .jks no Git!"
