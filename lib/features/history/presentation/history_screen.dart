// ============================================================
//  lib/features/history/presentation/history_screen.dart
//
//  Álbum de Evolução da Pele — Antes & Depois interativo
//  + Linha do tempo completa de análises
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/history_service.dart';
import '../data/history_entry.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<HistoryEntry> _entries = [];
  bool _isLoading = true;

  // Posição da barra de comparação Antes/Depois (0.0 a 1.0)
  double _sliderPosition = 0.5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await HistoryService.getEntries();
    setState(() {
      _entries = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFC8714A)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Evolução da Pele',
          style: TextStyle(
            color: Color(0xFFF5F0EC),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFC8714A),
          indicatorWeight: 3,
          labelColor: const Color(0xFFE8C9A0),
          unselectedLabelColor: const Color(0xFF8A7A6E),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: '✨ Antes & Depois'),
            Tab(text: '📅 Linha do Tempo'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFC8714A)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBeforeAfterTab(),
                _buildTimelineTab(),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TAB 1: ANTES & DEPOIS (SLIDER INTERATIVO)
  // ══════════════════════════════════════════════════════════
  Widget _buildBeforeAfterTab() {
    if (_entries.isEmpty) {
      return _buildEmptyState(
        title: 'Nenhuma análise ainda',
        desc: 'Faça sua primeira análise com IA para começar a acompanhar sua evolução!',
        buttonText: 'Fazer Análise Agora ✨',
        onTap: () => context.pop(),
      );
    }

    if (_entries.length == 1) {
      return _buildSingleEntryGuide();
    }

    // Mais antiga (antes) e mais recente (depois)
    final before = _entries.last;
    final after = _entries.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de progresso
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C1A10), Color(0xFF1C1712)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFC8714A).withAlpha(75)),
            ),
            child: Row(
              children: [
                const Text('📈', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Progresso da sua Pele',
                        style: TextStyle(
                          color: Color(0xFFF5F0EC),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Comparando ${before.formattedDate} com ${after.formattedDate}',
                        style: const TextStyle(
                          color: Color(0xFF8A7A6E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 20),

          // ── Slider Visual Antes & Depois ─────────────────
          if (before.imageBytes != null && after.imageBytes != null) ...[
            const Text(
              'Arraste a barra para comparar:',
              style: TextStyle(
                color: Color(0xFFE8C9A0),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _buildInteractiveSlider(before, after),
            const SizedBox(height: 20),
          ],

          // ── Métricas de Evolução ──────────────────────────
          const Text(
            'Comparativo de Scores:',
            style: TextStyle(
              color: Color(0xFFE8C9A0),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          _buildScoreComparisonCard(
            label: 'Score Geral de Saúde',
            emoji: '🌟',
            beforeVal: before.scoreGeral,
            afterVal: after.scoreGeral,
            higherIsBetter: true,
            maxVal: 100,
          ),
          const SizedBox(height: 8),

          _buildScoreComparisonCard(
            label: 'Oleosidade',
            emoji: '🛢️',
            beforeVal: before.oleosidade,
            afterVal: after.oleosidade,
            higherIsBetter: false,
            maxVal: 10,
          ),
          const SizedBox(height: 8),

          _buildScoreComparisonCard(
            label: 'Acne e Cravos',
            emoji: '😤',
            beforeVal: before.acne,
            afterVal: after.acne,
            higherIsBetter: false,
            maxVal: 10,
          ),
          const SizedBox(height: 8),

          _buildScoreComparisonCard(
            label: 'Manchas Solares',
            emoji: '☀️',
            beforeVal: before.manchas,
            afterVal: after.manchas,
            higherIsBetter: false,
            maxVal: 10,
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Slider Interativo Dividido ──────────────────────────
  Widget _buildInteractiveSlider(HistoryEntry before, HistoryEntry after) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 340.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFC8714A).withAlpha(60)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Imagem "Antes" (Fundo total)
                Positioned.fill(
                  child: Image.memory(
                    before.imageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),

                // Imagem "Depois" (Recortada pela posição do slider)
                Positioned.fill(
                  child: ClipRect(
                    clipper: _SliderClipper(_sliderPosition),
                    child: Image.memory(
                      after.imageBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Labels de data
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Antes (${before.formattedDate})',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8714A).withAlpha(200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Depois (${after.formattedDate})',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                // Linha divisória e puxador (Slider Handle)
                Positioned(
                  left: (width * _sliderPosition) - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  left: (width * _sliderPosition) - 18,
                  top: (height / 2) - 18,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8714A),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(150),
                          blurRadius: 8,
                        )
                      ],
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Center(
                      child: Icon(Icons.compare_arrows, color: Colors.white, size: 20),
                    ),
                  ),
                ),

                // Detector de arrasto transparente
                Positioned.fill(
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _sliderPosition =
                            (details.localPosition.dx / width).clamp(0.05, 0.95);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Card de Comparação de Score ──────────────────────────
  Widget _buildScoreComparisonCard({
    required String label,
    required String emoji,
    required int beforeVal,
    required int afterVal,
    required bool higherIsBetter,
    required int maxVal,
  }) {
    final diff = afterVal - beforeVal;
    final isImproved = higherIsBetter ? diff > 0 : diff < 0;
    final isSame = diff == 0;

    Color badgeColor;
    String diffText;

    if (isSame) {
      badgeColor = const Color(0xFF8A7A6E);
      diffText = 'Estável';
    } else if (isImproved) {
      badgeColor = const Color(0xFF6AB187);
      diffText = higherIsBetter ? '+$diff' : '$diff';
    } else {
      badgeColor = const Color(0xFFD96B6B);
      diffText = higherIsBetter ? '$diff' : '+$diff';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1712),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C1A10)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFF5F0EC),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$beforeVal ➔ $afterVal',
            style: const TextStyle(
              color: Color(0xFFE8C9A0),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withAlpha(75)),
            ),
            child: Text(
              diffText,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Guia para usuário que só tem 1 análise ────────────────
  Widget _buildSingleEntryGuide() {
    final first = _entries.first;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 64))
                .animate()
                .scale(curve: Curves.elasticOut),
            const SizedBox(height: 16),
            const Text(
              'Sua jornada de pele começou!',
              style: TextStyle(
                color: Color(0xFFF5F0EC),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Primeira análise registrada em ${first.formattedDate}.\n\n'
              'Siga sua rotina de skincare recomendada e volte daqui a alguns dias para sua 2ª análise. '
              'A barra de comparação interativa Antes & Depois será ativada automaticamente!',
              style: const TextStyle(
                color: Color(0xFF8A7A6E),
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8714A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Ver Detalhes da 1ª Análise ➔'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TAB 2: LINHA DO TEMPO COMPLETA
  // ══════════════════════════════════════════════════════════
  Widget _buildTimelineTab() {
    if (_entries.isEmpty) {
      return _buildEmptyState(
        title: 'Nenhuma análise salva',
        desc: 'Suas análises concluídas aparecerão aqui organizadas por data.',
        buttonText: 'Fazer Diagnóstico ✨',
        onTap: () => context.pop(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _buildTimelineCard(entry, isLatest: index == 0);
      },
    );
  }

  Widget _buildTimelineCard(HistoryEntry entry, {required bool isLatest}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1712),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLatest
              ? const Color(0xFFC8714A)
              : const Color(0xFF2C1A10),
          width: isLatest ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Foto miniatura ou ícone
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 60,
              height: 75,
              color: const Color(0xFF2C1A10),
              child: entry.imageBytes != null
                  ? Image.memory(entry.imageBytes!, fit: BoxFit.cover)
                  : const Center(
                      child: Text('👤', style: TextStyle(fontSize: 24)),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Informações da análise
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.formattedDate,
                      style: const TextStyle(
                        color: Color(0xFF8A7A6E),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isLatest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC8714A).withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Mais Recente',
                          style: TextStyle(
                            color: Color(0xFFC8714A),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Pele ${_capitalize(entry.skinType)}',
                  style: const TextStyle(
                    color: Color(0xFFF5F0EC),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),

                // Tags de métricas
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildMetricTag('🌟 ${entry.scoreGeral} pts'),
                    _buildMetricTag('🛢️ Óleo: ${entry.oleosidade}/10'),
                    _buildMetricTag('😤 Acne: ${entry.acne}/10'),
                  ],
                ),
              ],
            ),
          ),

          // Botão deletar
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFF8A7A6E), size: 18),
            onPressed: () => _confirmDelete(entry.id),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFFE8C9A0), fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String desc,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: Color(0xFFF5F0EC), fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: const TextStyle(color: Color(0xFF8A7A6E), fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8714A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1712),
        title: const Text('Excluir análise?', style: TextStyle(color: Color(0xFFF5F0EC))),
        content: const Text(
          'Esta análise será removida permanentemente do seu histórico.',
          style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF8A7A6E))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await HistoryService.deleteEntry(id);
              _loadHistory();
            },
            child: const Text('Excluir', style: TextStyle(color: Color(0xFFD96B6B))),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

// ── Clipper para o Slider Dividido ────────────────────────
class _SliderClipper extends CustomClipper<Rect> {
  final double position; // 0.0 a 1.0
  _SliderClipper(this.position);

  @override
  Rect getClip(Size size) {
    // Revela do lado direito até a posição do slider
    return Rect.fromLTRB(size.width * position, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_SliderClipper oldClipper) => oldClipper.position != position;
}
