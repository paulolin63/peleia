// ============================================================
//  lib/core/services/privacy_service.dart
//
//  Transparência de Dados, LGPD e Política de Retenção de Imagens
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_service.dart';
import 'gemini_skin_service.dart';
import 'history_thumb_store.dart';

import '../theme/app_theme.dart';

class AccountDeletionResult {
  final bool success;
  final String? error;

  const AccountDeletionResult({required this.success, this.error});
}

class PrivacyService {
  /// URL pública para solicitação de exclusão de conta via web (exigência do Google Play)
  static const String webDeletionUrl = 'https://peleia.pages.dev/delete-account.html';

  /// Exclui a conta e todos os dados associados (remoto e local).
  /// Só retorna sucesso se a exclusão remota e de autenticação tiverem sido confirmadas.
  static Future<AccountDeletionResult> deleteAccountAndData() async {
    try {
      // 1. Exclui a conta remota e cotas no servidor Cloudflare Worker
      final remoteSuccess = await GeminiSkinService.instance.deleteRemoteAccount();
      if (!remoteSuccess) {
        return const AccountDeletionResult(
          success: false,
          error: 'Não foi possível conectar ao servidor para excluir sua conta. Verifique sua conexão com a internet e tente novamente.',
        );
      }

      // 2. Exclui o usuário no Firebase Auth
      final authSuccess = await AuthService.deleteAccount();
      if (!authSuccess) {
        return const AccountDeletionResult(
          success: false,
          error: 'Não foi possível excluir suas credenciais de autenticação no momento. Verifique sua conexão e tente novamente.',
        );
      }

      // 3. Purge completo dos dados locais no aparelho
      final prefs = await SharedPreferences.getInstance();
      const exact = [
        'peleia_skin_history_entries_v1',
        'quota_free_analysis_used',
        'quota_free_scans_used',
        'quota_free_analysis_used_v2',
        'quota_free_scans_used_v2',
        'quota_sos_credits',
        'quota_pro_last_scan_date',
        'quota_pro_scans_today_count',
        'user_profile_v1',
        'user_age_group',
        'user_outdoor_exposure',
        'user_skin_type_quiz',
        'is_premium',
      ];
      for (final key in prefs.getKeys().toList()) {
        if (exact.contains(key) || key.startsWith('routine_')) {
          await prefs.remove(key);
        }
      }

      try {
        await HistoryThumbStore.clearAll();
      } catch (e) {
        debugPrint('⚠️ Erro ao limpar thumbs do histórico: $e');
      }

      // Limpa arquivos temporários de fotos capturadas pela câmera
      if (!kIsWeb) {
        try {
          final tempDir = await getTemporaryDirectory();
          if (tempDir.existsSync()) {
            final files = tempDir.listSync();
            for (final file in files) {
              final path = file.path.toLowerCase();
              if (path.contains('image_picker') ||
                  path.contains('peleia') ||
                  path.endsWith('.jpg') ||
                  path.endsWith('.png')) {
                file.deleteSync(recursive: true);
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao limpar arquivos temporários: $e');
        }
      }

      debugPrint('🗑️ Purge completo de dados e arquivos locais realizado.');
      return const AccountDeletionResult(success: true);
    } catch (e) {
      debugPrint('⚠️ Erro ao purgar dados: $e');
      return AccountDeletionResult(
        success: false,
        error: 'Ocorreu um erro inesperado ao excluir seus dados: $e',
      );
    }
  }

  /// Alias de retrocompatibilidade
  static Future<AccountDeletionResult> purgeAllUserData() async {
    return await deleteAccountAndData();
  }

  /// Exibe a política de privacidade e transparência de processamento de IA
  static void showPrivacyNoticeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Text('🔒', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Text(
                    'Privacidade & Retenção de Dados',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Em conformidade com a Lei Geral de Proteção de Dados (LGPD - Lei nº 13.709/2018) '
                'e com as diretrizes de transparência das lojas de aplicativos:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),

              _buildPrivacyPoint(
                emoji: '📱',
                title: 'Armazenamento Principal no Aparelho',
                desc: 'Suas fotos, seu histórico e o que você declara (tipo de pele, alergias, '
                    'gestação ou observação pessoal) ficam no armazenamento do seu telefone. '
                    'Não mantemos banco de dados externo com suas selfies.',
              ),
              const SizedBox(height: 14),

              _buildPrivacyPoint(
                emoji: '☁️',
                title: 'Processamento Temporário pela IA',
                desc: 'No momento do escaneamento, a foto e o perfil que você declarou '
                    '(idade, sol, ingredientes a evitar e observação) são transmitidos sob conexão '
                    'criptografada (TLS) ao provedor Google Gemini para montar a rotina. '
                    'Alergia, gestação e condição de pele são dados sensíveis e só saem do aparelho nessa hora.',
              ),
              const SizedBox(height: 14),

              _buildPrivacyPoint(
                emoji: '🛡️',
                title: 'Transparência sobre o Processamento pelo Provedor',
                desc: 'As imagens enviadas para análise são processadas pelo serviço de IA utilizado pelo PeleIA. '
                    'A retenção de conteúdo e de dados técnicos pelo provedor segue as condições aplicáveis ao serviço '
                    'e aos recursos utilizados. Em serviços pagos da Gemini API, determinados registros de solicitações '
                    'e respostas podem ser mantidos por período limitado para fins de segurança e prevenção de abusos.\n\n'
                    'O PeleIA não armazena intencionalmente imagens em seus próprios registros de aplicação, ferramentas de telemetria ou servidores.',
              ),
              const SizedBox(height: 14),

              _buildPrivacyPoint(
                emoji: '🗑️',
                title: 'Direito ao Esquecimento e Exclusão de Conta (LGPD)',
                desc: 'Você pode excluir permanentemente sua conta, fotos e todo o histórico a qualquer momento '
                    'diretamente no app acessando Perfil > Configurações > Excluir Conta.\n\n'
                    'Caso tenha desinstalado o app ou prefira solicitar pela web, disponibilizamos uma página oficial de solicitação de exclusão.',
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(webDeletionUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 14, color: AppTheme.primary),
                  label: const Text(
                    'Página Web de Solicitação de Exclusão →',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _buildPrivacyPoint(
                emoji: '🤝',
                title: 'Transparência de Links de Afiliados',
                desc: 'O PeleIA participa de programas de afiliados (Mercado Livre, Amazon e Shopee). '
                    'Recomendamos produtos adequados à sua análise de pele. '
                    'Caso realize uma compra através dos nossos links, podemos receber uma comissão sem qualquer custo adicional para você.',
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Entendido e Ciente',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildPrivacyPoint({
    required String emoji,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
