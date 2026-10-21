// ============================================================
//  lib/features/report/presentation/result_screen.dart
//
//  Tela de resultados — scores + relatório PT-BR + produtos afiliados
// ============================================================
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../paywall/presentation/paywall_provider.dart';
import '../../scan/data/skin_analysis_result.dart';
import '../../scan/presentation/scan_provider.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanProvider);
    final analysis = state.analysis;

    if (analysis == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              const Text(
                'Nenhuma análise encontrada',
                style: TextStyle(color: Color(0xFF8A7A6E)),
              ),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text(
                  'Fazer nova análise',
                  style: TextStyle(color: Color(0xFFC8714A)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F0F),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFC8714A)),
              onPressed: () {
                ref.read(scanProvider.notifier).reset();
                context.go('/');
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroHeader(analysis, state.imageBytes != null
                  ? Image.memory(state.imageBytes!, fit: BoxFit.cover)
                  : null),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),

                // ── Score geral ──────────────────────────────
                _buildOverallScore(analysis)
                    .animate()
                    .fadeIn(delay: 100.ms)
                    .slideY(begin: 0.2),

                const SizedBox(height: 16),

                // ── Score breakdown ──────────────────────────
                _buildScoreBreakdown(analysis)
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .slideY(begin: 0.2),

                const SizedBox(height: 16),

                // ── Relatório PT-BR ──────────────────────────
                if (state.report != null)
                  _buildReport(state.report!)
                      .animate()
                      .fadeIn(delay: 300.ms)
                      .slideY(begin: 0.2),

                const SizedBox(height: 16),

                // ── Produtos afiliados ───────────────────────
                if (state.products.isNotEmpty)
                  _buildProducts(state.products)
                      .animate()
                      .fadeIn(delay: 400.ms)
                      .slideY(begin: 0.2),

                const SizedBox(height: 24),

                // ── Banner Premium ───────────────────────────
                _buildPremiumBanner(context)
                    .animate()
                    .fadeIn(delay: 450.ms)
                    .slideY(begin: 0.2),

                const SizedBox(height: 14),

                // ── Botão Ver Evolução (Antes & Depois) ──────────
                GestureDetector(
                  onTap: () => context.push('/history'),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2C1A10), Color(0xFF1C1712)],
                      ),
                      border: Border.all(
                        color: const Color(0xFFC8714A).withAlpha(120),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('📈', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text(
                          'Ver Minha Evolução (Antes & Depois)',
                          style: TextStyle(
                            color: Color(0xFFE8C9A0),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 480.ms),

                const SizedBox(height: 12),

                // ── Botão nova análise ───────────────────────
                GestureDetector(
                  onTap: () {
                    ref.read(scanProvider.notifier).reset();
                    context.go('/');
                  },
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFC8714A).withAlpha(100),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🔄', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text(
                          'Nova Análise',
                          style: TextStyle(
                            color: Color(0xFFC8714A),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(SkinAnalysisRaw analysis, Widget? photo) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            analysis.skinTypeColor.withAlpha(50),
            const Color(0xFF0F0F0F),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
          child: Row(
            children: [
              // Foto ou ícone
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  width: 80,
                  height: 96,
                  color: const Color(0xFF2C1A10),
                  child: photo ??
                      const Center(
                        child: Text('👤', style: TextStyle(fontSize: 40)),
                      ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: analysis.skinTypeColor.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: analysis.skinTypeColor.withAlpha(75),
                        ),
                      ),
                      child: Text(
                        'Diagnóstico Concluído ✓',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: analysis.skinTypeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      analysis.skinTypeLabel,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF5F0EC),
                      ),
                    ),
                    if (analysis.problemasDetectados.isNotEmpty)
                      Text(
                        'com ${_formatProblemas(analysis.problemasDetectados)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFC8714A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverallScore(SkinAnalysisRaw analysis) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1712),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: analysis.scoreColor.withAlpha(75),
        ),
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _ScoreRingPainter(
                score: analysis.scoreGeral,
                color: analysis.scoreColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${analysis.scoreGeral}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: analysis.scoreColor,
                      ),
                    ),
                    const Text(
                      '/100',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8A7A6E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Score de Saúde da Pele',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF5F0EC),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getScoreMessage(analysis.scoreGeral),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A7A6E),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A44A).withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFE8A44A).withAlpha(75),
                    ),
                  ),
                  child: Text(
                    'Confiança da IA: ${(analysis.confianca * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE8A44A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBreakdown(SkinAnalysisRaw analysis) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1712),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC8714A).withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Análise Detalhada',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE8C9A0),
            ),
          ),
          const SizedBox(height: 16),
          ...analysis.scores.items.map((item) => _buildScoreRow(item)),
        ],
      ),
    );
  }

  Widget _buildScoreRow(ScoreItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFE8C9A0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                item.scoreLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: item.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.normalized,
              backgroundColor: Colors.white.withAlpha(20),
              valueColor: AlwaysStoppedAnimation<Color>(item.color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(String report) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1712),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC8714A).withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📋 Seu Relatório Personalizado',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE8C9A0),
            ),
          ),
          const SizedBox(height: 16),
          // Renderiza o texto markdown simples
          Text(
            report,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFF5F0EC),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProducts(List<AffiliateProduct> products) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1712),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC8714A).withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '🛍️ Produtos Recomendados',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE8C9A0),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6AB187).withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF6AB187).withAlpha(75)),
                ),
                child: const Text(
                  'PARCEIRO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6AB187),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...products.map((product) => _buildProductCard(product)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6AB187).withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6AB187).withAlpha(50)),
            ),
            child: Column(
              children: [
                Text(
                  '💰 Rotina completa estimada: ~R\$ ${_calcTotal(products).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6AB187),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  '*Preços estimados. Valores sujeitos a alteração e promoções na loja parceira.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8A7A6E),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(AffiliateProduct product) {
    return GestureDetector(
      onTap: () => _openAffiliateLink(product.affiliateUrl),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFC8714A).withAlpha(40),
          ),
        ),
        child: Row(
          children: [
            // Ícone do produto
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2C1A10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  product.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF5F0EC),
                    ),
                  ),
                  Text(
                    product.brand,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A7A6E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC8714A).withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFC8714A).withAlpha(75),
                          ),
                        ),
                        child: Text(
                          product.priceFormatted,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE8C9A0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        product.storeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6AB187),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFFC8714A),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  Widget _buildPremiumBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/premium'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2C1A10), Color(0xFF1C1712)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC8714A).withAlpha(100)),
        ),
        child: Row(
          children: [
            const Text('💎', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Desbloqueie o Premium',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE8C9A0),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Análises ilimitadas + histórico + alertas UV.\n3 dias grátis para começar!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A7A6E),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Ver planos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers originais ─────────────────────────────────────

  String _formatProblemas(List<String> problemas) {
    if (problemas.isEmpty) return '';
    final labels = {
      'acne_ativa': 'tendência à acne',
      'cravos': 'cravos',
      'manchas_solares': 'manchas solares',
      'oleosidade_excessiva': 'oleosidade excessiva',
      'poros_dilatados': 'poros dilatados',
      'melasma': 'melasma',
      'vermelhidao': 'vermelhidão',
    };
    return labels[problemas.first] ?? problemas.first.replaceAll('_', ' ');
  }

  String _getScoreMessage(int score) {
    if (score >= 85) return 'Sua pele está ótima! Continue com a rotina.';
    if (score >= 70) return 'Pele em bom estado com alguns pontos de atenção.';
    if (score >= 55) return 'Sua pele precisa de cuidados específicos. Veja a rotina.';
    return 'Atenção! Sua pele precisa de cuidados urgentes.';
  }

  double _calcTotal(List<AffiliateProduct> products) {
    return products.fold(0.0, (sum, p) => sum + p.priceEstimated);
  }

  Future<void> _openAffiliateLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Custom painter para o ring de score ──────────────────
class _ScoreRingPainter extends CustomPainter {
  final int score;
  final Color color;

  _ScoreRingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    // Background ring
    final bgPaint = Paint()
      ..color = color.withAlpha(40)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Score arc
    final scorePaint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = (score / 100) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      scorePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) =>
      old.score != score || old.color != color;
}
