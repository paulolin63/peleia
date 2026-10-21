// ============================================================
//  lib/features/dashboard/presentation/dashboard_screen.dart
//
//  Painel Diário de Skincare (Dashboard)
//  - Saudação personalizada e status da pele
//  - Alerta UV e clima brasileiro do dia
//  - Checklist diário de rotina (Manhã e Noite com checkboxes)
//  - Atalhos para Nova Análise, Evolução Antes & Depois e Premium
// ============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/history_service.dart';
import '../../../core/services/quota_service.dart';
import '../../history/data/history_entry.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  HistoryEntry? _latestEntry;
  bool _isLoading = true;
  bool _isPro = false;
  QuotaStatus? _quotaStatus;

  // Checklist da rotina de hoje
  bool _isMorningTab = true;
  Set<int> _morningChecked = {};
  Set<int> _nightChecked = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool('is_premium') ?? false;

    // Carrega última análise do histórico
    final entries = await HistoryService.getEntries();
    if (entries.isNotEmpty) {
      _latestEntry = entries.first;
    }

    // Carrega status da cota
    _quotaStatus = await QuotaService.checkQuota(isPro: _isPro);

    // Carrega checklist do dia atual
    final today = _getTodayKey();
    final morningSaved = prefs.getStringList('routine_morning_$today') ?? [];
    final nightSaved = prefs.getStringList('routine_night_$today') ?? [];

    _morningChecked = morningSaved.map(int.parse).toSet();
    _nightChecked = nightSaved.map(int.parse).toSet();

    setState(() => _isLoading = false);
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}_${now.month}_${now.day}';
  }

  Future<void> _toggleStep(int index, bool isMorning) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayKey();

    setState(() {
      if (isMorning) {
        if (_morningChecked.contains(index)) {
          _morningChecked.remove(index);
        } else {
          _morningChecked.add(index);
        }
        prefs.setStringList(
          'routine_morning_$today',
          _morningChecked.map((i) => i.toString()).toList(),
        );
      } else {
        if (_nightChecked.contains(index)) {
          _nightChecked.remove(index);
        } else {
          _nightChecked.add(index);
        }
        prefs.setStringList(
          'routine_night_$today',
          _nightChecked.map((i) => i.toString()).toList(),
        );
      }
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Bom dia';
    if (hour >= 12 && hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC8714A)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFC8714A),
          backgroundColor: const Color(0xFF1C1712),
          onRefresh: _loadDashboardData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Header Superior ─────────────────────────
                    _buildTopHeader(),

                    const SizedBox(height: 20),

                    // ── Card de Alerta UV e Clima BR ────────────
                    _buildUvAlertCard(),

                    const SizedBox(height: 18),

                    // ── Card de Status da Pele / Última Análise ─
                    _buildSkinStatusCard(),

                    const SizedBox(height: 22),

                    // ── Checklist da Rotina de Hoje ─────────────
                    _buildDailyRoutineSection(),

                    const SizedBox(height: 24),

                    // ── Botão Principal: Nova Análise com IA ────
                    _buildScanCTA(),

                    const SizedBox(height: 16),

                    // ── Atalhos Rápidos (Evolução & Premium) ─────
                    _buildQuickActionCards(),

                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Header Superior com Saudação e Badges ──────────────
  Widget _buildTopHeader() {
    return Row(
      children: [
        // Avatar ou Logo
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Text('✨', style: TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()}, maravilhosa! 👋',
              style: const TextStyle(
                color: Color(0xFF8A7A6E),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'PeleIA Diário',
              style: TextStyle(
                color: Color(0xFFF5F0EC),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const Spacer(),

        // Botão Histórico
        IconButton(
          onPressed: () => context.push('/history').then((_) => _loadDashboardData()),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1712),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC8714A).withAlpha(50)),
            ),
            child: const Icon(Icons.history, color: Color(0xFFE8C9A0), size: 20),
          ),
        ),

        // Badge Pro ou Botão Assinar
        GestureDetector(
          onTap: () => context.push('/premium').then((_) => _loadDashboardData()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: _isPro
                  ? const LinearGradient(colors: [Color(0xFF6AB187), Color(0xFF4A9268)])
                  : const LinearGradient(colors: [Color(0xFFC8714A), Color(0xFFE8A44A)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(_isPro ? '💎 PRO' : '⚡ ASSINAR',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    )),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  // ── 2. Card de Alerta UV e Clima Tropical do Brasil ───────
  Widget _buildUvAlertCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C1A10), Color(0xFF1C1712)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8A44A).withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8A44A).withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('☀️', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Índice UV: 9.0 (Muito Alto)',
                      style: TextStyle(
                        color: Color(0xFFE8A44A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD96B6B).withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'BRASIL',
                        style: TextStyle(color: Color(0xFFD96B6B), fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Radiação intensa hoje. Aplique protetor FPS 50+ toque seco pela manhã e reaplique a cada 2h se exposta ao sol ou suor.',
                  style: TextStyle(
                    color: Color(0xFF8A7A6E),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  // ── 3. Card de Status da Pele / Última Análise ────────────
  Widget _buildSkinStatusCard() {
    if (_latestEntry == null) {
      // Usuário novo — convite para primeira análise
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1712),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC8714A).withAlpha(50)),
        ),
        child: Row(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comece seu Diagnóstico',
                    style: TextStyle(
                      color: Color(0xFFF5F0EC),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Tire uma selfie para a IA mapear sua oleosidade, acne e manchas em 30 segundos.',
                    style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 250.ms);
    }

    // Usuário já tem histórico
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1712),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC8714A).withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sua Pele Atual: Pele ${_capitalize(_latestEntry!.skinType)}',
                style: const TextStyle(
                  color: Color(0xFFF5F0EC),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${_latestEntry!.formattedDate}',
                style: const TextStyle(color: Color(0xFF8A7A6E), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniMetric(
                label: 'Saúde Geral',
                value: '${_latestEntry!.scoreGeral}',
                suffix: 'pts',
                color: const Color(0xFF6AB187),
              ),
              _buildMiniMetric(
                label: 'Oleosidade',
                value: '${_latestEntry!.oleosidade}',
                suffix: '/10',
                color: const Color(0xFFE8A44A),
              ),
              _buildMiniMetric(
                label: 'Acne/Cravos',
                value: '${_latestEntry!.acne}',
                suffix: '/10',
                color: const Color(0xFFD96B6B),
              ),
              _buildMiniMetric(
                label: 'Manchas UV',
                value: '${_latestEntry!.manchas}',
                suffix: '/10',
                color: const Color(0xFFE8A44A),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required String suffix,
    required Color color,
  }) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: ' $suffix',
                style: const TextStyle(color: Color(0xFF8A7A6E), fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8A7A6E), fontSize: 11),
        ),
      ],
    );
  }

  // ── 4. Checklist da Rotina de Hoje (Manhã / Noite) ────────
  Widget _buildDailyRoutineSection() {
    final currentChecked = _isMorningTab ? _morningChecked : _nightChecked;
    const totalSteps = 3;
    final completedCount = currentChecked.length;

    final morningSteps = [
      ('🧴', 'Limpeza Facial', 'Gel com Ácido Salicílico ou Espuma suave'),
      ('💧', 'Sérum de Tratamento', 'Niacinamida 10% (anti-brilho e poros)'),
      ('☀️', 'Protetor Solar FPS 50+', 'Toque seco oil-free — Não pule este passo!'),
    ];

    final nightSteps = [
      ('🧼', 'Double Cleansing', 'Remoção completa do protetor solar e poluição'),
      ('✨', 'Tratamento Noturno', 'Ácido Azelaico ou Renovador celular'),
      ('💦', 'Hidratação Leve', 'Gel facial sem óleo mineral (textura aqua)'),
    ];

    final activeSteps = _isMorningTab ? morningSteps : nightSteps;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1712),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2C1A10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sua Rotina Diária',
                style: TextStyle(
                  color: Color(0xFFF5F0EC),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              // Toggle Manhã / Noite
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildRoutineToggle('🌅 Manhã', _isMorningTab, () {
                      setState(() => _isMorningTab = true);
                    }),
                    _buildRoutineToggle('🌙 Noite', !_isMorningTab, () {
                      setState(() => _isMorningTab = false);
                    }),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Barra de progresso da rotina
          Row(
            children: [
              Text(
                '$completedCount de $totalSteps passos concluídos',
                style: const TextStyle(color: Color(0xFFE8C9A0), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (completedCount == totalSteps)
                const Text('🎉 Tudo pronto!', style: TextStyle(color: Color(0xFF6AB187), fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completedCount / totalSteps,
              backgroundColor: Colors.white.withAlpha(10),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFC8714A)),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 16),

          // Lista interativa de passos
          ...activeSteps.asMap().entries.map((entry) {
            final idx = entry.key;
            final (emoji, title, desc) = entry.value;
            final isChecked = currentChecked.contains(idx);

            return GestureDetector(
              onTap: () => _toggleStep(idx, _isMorningTab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isChecked ? const Color(0xFF6AB187).withAlpha(15) : const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isChecked ? const Color(0xFF6AB187).withAlpha(60) : const Color(0xFF2C1A10),
                  ),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isChecked ? const Color(0xFF6AB187) : const Color(0xFFF5F0EC),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              decoration: isChecked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          Text(
                            desc,
                            style: TextStyle(
                              color: const Color(0xFF8A7A6E),
                              fontSize: 11,
                              decoration: isChecked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isChecked ? const Color(0xFF6AB187) : const Color(0xFF8A7A6E),
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms);
  }

  Widget _buildRoutineToggle(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC8714A) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF8A7A6E),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── 5. Botão de Destaque: Nova Análise com IA ─────────────
  Widget _buildScanCTA() {
    return GestureDetector(
      onTap: () => context.push('/scan').then((_) => _loadDashboardData()),
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC8714A).withAlpha(90),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📸', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fazer Nova Análise Facial',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _quotaStatus?.statusText ?? 'Diagnóstico inteligente por IA',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 450.ms).scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1));
  }

  // ── 6. Atalhos Secundários (Antes & Depois + Premium) ─────
  Widget _buildQuickActionCards() {
    return Row(
      children: [
        // Antes & Depois
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/history').then((_) => _loadDashboardData()),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1712),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC8714A).withAlpha(50)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📈', style: TextStyle(fontSize: 22)),
                  SizedBox(height: 8),
                  Text(
                    'Antes & Depois',
                    style: TextStyle(
                      color: Color(0xFFF5F0EC),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ver evolução da pele',
                    style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Planos Pro
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/premium').then((_) => _loadDashboardData()),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1712),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6AB187).withAlpha(50)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💎', style: TextStyle(fontSize: 22)),
                  SizedBox(height: 8),
                  Text(
                    'PeleIA Pro',
                    style: TextStyle(
                      color: Color(0xFFF5F0EC),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Gerenciar assinatura',
                    style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 550.ms);
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
