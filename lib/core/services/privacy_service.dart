// ============================================================
//  lib/core/services/privacy_service.dart
//
//  Transparência de Dados, LGPD e Política de Retenção de Imagens
// ============================================================
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyService {
  /// Limpeza completa de todos os dados do usuário (LGPD compliance)
  static Future<void> purgeAllUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('peleia_skin_history_entries_v1');
      await prefs.remove('peleia_scans_today_v1');
      await prefs.remove('peleia_sos_credits_v1');

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
    } catch (e) {
      debugPrint('⚠️ Erro ao purgar dados: $e');
    }
  }

  /// Exibe a política de privacidade e transparência de processamento de IA
  static void showPrivacyNoticeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16120E),
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
                    color: Colors.white24,
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
                      color: Color(0xFFF5F0EC),
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
                style: TextStyle(color: Color(0xFFD4C2B2), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),

              _buildPrivacyPoint(
                emoji: '📱',
                title: 'Armazenamento Principal no Aparelho',
                desc: 'Suas fotos e históricos são salvos exclusivamente no armazenamento '
                    'local do seu próprio telefone. Não mantemos banco de dados externo com suas selfies.',
              ),
              const SizedBox(height: 14),

              _buildPrivacyPoint(
                emoji: '☁️',
                title: 'Processamento Temporário pela IA',
                desc: 'No momento do escaneamento, a foto é transmitida sob conexão criptografada (TLS) '
                    'ao provedor Google Gemini para a extração dos indicadores visuais.',
              ),
              const SizedBox(height: 14),

              _buildPrivacyPoint(
                emoji: '🛡️',
                title: 'Diretrizes do Provedor de IA (Google AI)',
                desc: 'Nas contas comerciais pagas, seus dados de entrada não são utilizados para '
                    'treinamento de modelos públicos. Conforme as regras oficiais do Google AI for Developers, '
                    'registros técnicos podem ser retidos por até 30 dias exclusivamente para monitoramento de segurança e abuso.',
              ),
              const SizedBox(height: 14),

              _buildPrivacyPoint(
                emoji: '🗑️',
                title: 'Direito ao Esquecimento e Exclusão Total',
                desc: 'Você pode excluir seu histórico a qualquer momento pelo botão de lixeira no app. '
                    'Ao confirmar, todas as fotos e índices são apagados definitivamente do seu telefone.',
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC8714A),
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
                  color: Color(0xFFE8C9A0),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(
                  color: Color(0xFF8A7A6E),
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
