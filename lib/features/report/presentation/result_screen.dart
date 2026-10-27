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

import '../../../core/config/app_config.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/services/comparison_service.dart';
import '../../history/data/history_entry.dart';
import '../../scan/data/skin_analysis_result.dart';
import '../../scan/presentation/scan_provider.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanProvider);
    final texts = ref.watch(appConfigProvider).valueOrNull?.texts ?? AppTexts.fallback;
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

                // ── Memória Inteligente / Evolução ───────────
                _buildEvolutionCard(
                  analysis,
                  state.previousEntry,
                  state.comparison,
                )
                    .animate()
                    .fadeIn(delay: 150.ms)
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
                if (state.products.isNotEmpty || state.hiddenProducts > 0 || state.missingSunscreen)
                  _buildProducts(state)
                      .animate()
                      .fadeIn(delay: 400.ms)
                      .slideY(begin: 0.2),

                const SizedBox(height: 24),

                // ── Banner Premium ───────────────────────────
                _buildPremiumBanner(context, texts)
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

                const SizedBox(height: 24),

                // ── Aviso Regulatório / ANVISA / CFM ──────────
                _buildRegulatoryDisclaimer()
                    .animate()
                    .fadeIn(delay: 550.ms),

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
                        'Análise Concluída ✓',
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
                  'Indicador Visual da Pele',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF5F0EC),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Referência cosmética • Não é diagnóstico clínico',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8A7A6E),
                    fontStyle: FontStyle.italic,
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

  Widget _buildEvolutionCard(
    SkinAnalysisRaw analysis,
    HistoryEntry? prev,
    SkinComparisonResult? comp,
  ) {
    if (prev != null) {
      final scoreDelta = analysis.scoreGeral - prev.scoreGeral;
      final daysDiff = DateTime.now().difference(prev.date).inDays;
      final timeAgoStr = daysDiff == 0
          ? 'Hoje mais cedo'
          : daysDiff == 1
              ? 'Ontem'
              : 'Há $daysDiff dias (${prev.formattedDate})';

      final isWithinVariance = comp?.isWithinNormalVariance ?? (scoreDelta.abs() <= 2);

      final isBetter = scoreDelta > 0 && !isWithinVariance;

      final deltaColor = isWithinVariance
          ? const Color(0xFFE8A44A)
          : (isBetter ? const Color(0xFF6AB187) : const Color(0xFFE05353));

      final deltaText = isWithinVariance
          ? 'Variação pequena • Inconclusivo'
          : (isBetter
              ? '+$scoreDelta pts (Tendência de melhora)'
              : '$scoreDelta pts (Oscilação visual)');

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF241C16),
              Color(0xFF1C1712),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFC8714A).withAlpha(90),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8714A).withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🧠', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Acompanhamento de Rotina PeleIA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE8C9A0),
                        ),
                      ),
                      Text(
                        'Comparado com: $timeAgoStr',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A7A6E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: deltaColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: deltaColor.withAlpha(80)),
                  ),
                  child: Text(
                    deltaText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: deltaColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Linha com comparação de métricas chave
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF120E0B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricDelta(
                    label: 'Indicador',
                    oldVal: '${prev.scoreGeral}',
                    newVal: '${analysis.scoreGeral}',
                    improved: analysis.scoreGeral >= prev.scoreGeral,
                  ),
                  _buildMetricDivider(),
                  _buildMetricDelta(
                    label: 'Acne',
                    oldVal: '${prev.acne}',
                    newVal: '${analysis.scores.acneCravos}',
                    improved: analysis.scores.acneCravos <= prev.acne,
                  ),
                  _buildMetricDivider(),
                  _buildMetricDelta(
                    label: 'Oleosidade',
                    oldVal: '${prev.oleosidade}',
                    newVal: '${analysis.scores.oleosidade}',
                    improved: analysis.scores.oleosidade <= prev.oleosidade,
                  ),
                  _buildMetricDivider(),
                  _buildMetricDelta(
                    label: 'Hidratação',
                    oldVal: '${prev.hidratacao}',
                    newVal: '${analysis.scores.hidratacao}',
                    improved: analysis.scores.hidratacao >= prev.hidratacao,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 13, color: Color(0xFFC8714A)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isWithinVariance
                        ? 'Variação pequena que não permite concluir melhora ou piora. Acompanhe nas próximas semanas sob luz similar.'
                        : 'Tendência calculada matematicamente. As orientações cosméticas foram adaptadas abaixo.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD4C2B2),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Primeira análise (Marco Zero / Baseline)
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1712),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6AB187).withAlpha(60),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6AB187).withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Text('🌱', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Primeira Análise Concluída!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE8C9A0),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Seu indicador inicial (${analysis.scoreGeral}/100) foi salvo de forma privada no aparelho. Em selfies futuras sob condições similares, mostraremos sua evolução visual.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A7A6E),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withAlpha(15),
    );
  }

  Widget _buildMetricDelta({
    required String label,
    required String oldVal,
    required String newVal,
    required bool improved,
  }) {
    final color = improved ? const Color(0xFF6AB187) : const Color(0xFFE05353);
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF8A7A6E),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              oldVal,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8A7A6E),
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_forward, size: 10, color: Color(0xFF8A7A6E)),
            const SizedBox(width: 3),
            Text(
              newVal,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegulatoryDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16120E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8714A).withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🩺', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aviso Regulatório & Médico (ANVISA / CFM)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE8C9A0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'O PeleIA é um assistente de rotina de cuidados cosméticos e higiene pessoal. '
            'As avaliações visuais por IA são estimativas orientativas de referência e NÃO '
            'constituem diagnóstico médico, exame clínico ou prescrição dermatológica.\n\n'
            'Em caso de dor, inflamação ativa, lesões irregulares que sangram ou mudam de cor, '
            'consulte sempre presencialmente um médico dermatologista credenciado pela SBD.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF8A7A6E),
              height: 1.5,
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

  Widget _buildProducts(ScanState state) {
    final products = state.products;
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
          if (state.hiddenProducts > 0 || state.missingSunscreen)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _avoidanceNotice(state),
                style: const TextStyle(fontSize: 12, color: Color(0xFFE8C9A0), height: 1.4),
              ),
            ),
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

  Widget _buildPremiumBanner(BuildContext context, AppTexts texts) {
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texts.premiumBannerTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE8C9A0),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    texts.premiumBannerSubtitle,
                    style: const TextStyle(
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

  String _avoidanceNotice(ScanState state) {
    final labels = state.avoidedLabels.join(', ');
    final hidden = state.hiddenProducts > 0
        ? 'Ocultamos ${state.hiddenProducts} produto(s)${labels.isEmpty ? '' : ' com $labels'}.'
        : '';
    final sun = state.missingSunscreen
        ? ' Nenhum protetor do catálogo serve ao seu perfil. Procure um FPS 50+ sem esses ingredientes e confira o rótulo (INCI).'
        : ' Confira o rótulo (INCI) antes de comprar.';
    return '$hidden$sun'.trim();
  }

  double _calcTotal(List<AffiliateProduct> products) {
    return products.fold(0.0, (sum, p) => sum + p.priceEstimated);
  }

  Future<void> _openAffiliateLink(String url) async {
    if (url.trim().isEmpty) return;
    try {
      final uri = Uri.parse(url.trim());
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Erro ao abrir link de produto: $e');
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
