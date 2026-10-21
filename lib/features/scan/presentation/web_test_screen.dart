// ============================================================
//  lib/features/scan/presentation/web_test_screen.dart
//
//  Tela de teste para Web/macOS — bypassa câmera
//  Permite testar a IA com URLs de imagens de rosto
// ============================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/gemini_skin_service.dart';
import '../../../core/services/quota_service.dart';
import '../data/skin_analysis_result.dart';
import 'scan_provider.dart';

class WebTestScreen extends ConsumerStatefulWidget {
  const WebTestScreen({super.key});

  @override
  ConsumerState<WebTestScreen> createState() => _WebTestScreenState();
}

class _WebTestScreenState extends ConsumerState<WebTestScreen> {
  bool _isLoading = false;
  String _status = '';
  String? _errorMsg;

  // Imagens de teste públicas (rostos)
  final List<Map<String, String>> _testImages = [
    {
      'label': '👩🏽 Pele Morena',
      'url':
          'https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Gatto_europeo4.jpg/220px-Gatto_europeo4.jpg',
    },
    {
      'label': 'Usar galeria local',
      'url': 'local',
    },
  ];

  Future<void> _runAnalysisFromPicker() async {
    setState(() {
      _isLoading = true;
      _status = '📂 Abrindo galeria...';
      _errorMsg = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final isPro = prefs.getBool('is_premium') ?? false;
      final quota = await QuotaService.checkQuota(isPro: isPro);

      if (!quota.canScan) {
        setState(() {
          _isLoading = false;
          _status = '';
        });
        if (mounted) {
          if (quota.blockReason == QuotaBlockReason.proDailyExceeded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF1C1712),
                content: Text(quota.statusText, style: const TextStyle(color: Color(0xFFE8C9A0))),
              ),
            );
          } else {
            context.push('/premium');
          }
        }
        return;
      }

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (picked == null) {
        setState(() {
          _isLoading = false;
          _status = '';
        });
        return;
      }

      setState(() => _status = '🔬 Analisando com Gemini Vision...');

      final gemini = GeminiSkinService.instance;
      gemini.initialize();

      late SkinAnalysisRaw analysis;

      if (kIsWeb) {
        // Web: usa bytes diretamente
        final bytes = await picked.readAsBytes();
        analysis = await gemini.analyzeImageBytes(bytes);
      } else {
        // Mobile/Desktop: usa bytes via XFile (sem dart:io File)
        final bytes = await picked.readAsBytes();
        analysis = await gemini.analyzeImageBytes(bytes);
      }

      setState(() => _status = '📋 Gerando relatório PT-BR...');
      final report = await gemini.generateReport(analysis);
      final products = ProductCatalog.getRecommendations(analysis);

      // Consome cota
      await QuotaService.consumeQuota(isPro: isPro);

      // Salva no provider
      ref.read(scanProvider.notifier).setResultDirectly(
            analysis: analysis,
            report: report,
            products: products,
          );

      if (mounted) context.push('/result');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _status = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                        child: Text('✨', style: TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  RichText(
                    text: const TextSpan(children: [
                      TextSpan(
                          text: 'Pele',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF5F0EC))),
                      TextSpan(
                          text: 'IA',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFC8714A))),
                    ]),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8A44A).withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFE8A44A).withAlpha(75)),
                    ),
                    child: const Text(
                      '🧪 Modo Teste',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFE8A44A),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ).animate().fadeIn(),

              const SizedBox(height: 32),

              // Título
              const Text(
                'Teste a IA de\nDiagnóstico de Pele',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF5F0EC),
                    height: 1.2),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 8),

              const Text(
                'Selecione uma foto de rosto para analisar',
                style: TextStyle(fontSize: 14, color: Color(0xFF8A7A6E)),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 32),

              if (_isLoading) ...[
                // Loading state
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1712),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFC8714A).withAlpha(75)),
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFFC8714A),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _status,
                        style: const TextStyle(
                            color: Color(0xFFF5F0EC), fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Upload button
                GestureDetector(
                  onTap: _runAnalysisFromPicker,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC8714A).withAlpha(75),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Column(
                      children: const [
                        Text('📁', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 12),
                        Text(
                          'Selecionar Foto do Rosto',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'JPG, PNG — a IA vai analisar oleosidade,\nacne, manchas e risco UV',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms).scale(
                      begin: const Offset(0.95, 0.95),
                      end: const Offset(1, 1),
                    ),

                if (_errorMsg != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD96B6B).withAlpha(30),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFD96B6B).withAlpha(75)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('❌ ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: const TextStyle(
                                color: Color(0xFFD96B6B), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Dicas
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1712),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFC8714A).withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 3 Regras de Ouro para o Diagnóstico:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE8C9A0)),
                      ),
                      const SizedBox(height: 10),
                      ...[
                        '☀️ Fique de frente para luz natural (evite luz de costas)',
                        '✨ Desative o modo embelezador/filtro da câmera',
                        '🧼 Rosto limpo e sem maquiagem para ver os poros reais',
                        '📐 Rosto centralizado e alinhado na altura dos olhos',
                      ].map((tip) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              tip,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF8A7A6E)),
                            ),
                          )),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
