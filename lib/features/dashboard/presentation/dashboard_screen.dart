// ============================================================
//  lib/features/dashboard/presentation/dashboard_screen.dart
//
//  Painel Diário de Skincare (Dashboard)
//  - Saudação personalizada e status da pele
//  - Alerta UV e clima brasileiro do dia
//  - Checklist diário de rotina (Manhã e Noite com checkboxes)
//  - Atalhos para Nova Análise, Evolução Antes & Depois e Premium
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/localization/language_toggle_button.dart';
import '../../../core/profile/user_profile.dart';
import '../../../core/services/history_service.dart';
import '../../../core/services/quota_service.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../history/data/history_entry.dart';
import '../../profile/avoidance_fields.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  HistoryEntry? _latestEntry;
  bool _isLoading = true;
  bool _isPro = false;
  QuotaStatus? _quotaStatus;
  String? _ageGroup;
  String? _outdoorExposure;
  UserProfile _profile = const UserProfile();
  AppConfig? _config;

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
    final remotePro = await RevenueCatService.isPremium();
    if (remotePro) {
      _isPro = true;
      await prefs.setBool('is_premium', true);
    } else {
      _isPro = prefs.getBool('is_premium') ?? false;
    }
    _config = await RemoteConfigService.load();
    _profile = await UserProfileStore.load();

    // Carrega última análise do histórico
    final entries = await HistoryService.getEntries();
    if (entries.isNotEmpty) {
      _latestEntry = entries.first;
    }

    // Carrega status da cota
    _quotaStatus = await QuotaService.checkQuota(isPro: _isPro);

    // Carrega perfil declarado
    _ageGroup = _profile.ageGroup ?? '20_35';
    _outdoorExposure = _profile.outdoorExposure ?? 'outdoor_moderate';

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

                    const SizedBox(height: 12),

                    // ── Perfil Declarado do Usuário ─────────────
                    _buildUserProfileBadge(),

                    const SizedBox(height: 16),

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

        // Alternador de Idioma (PT / EN)
        const LanguageToggleButton(compact: true),
        const SizedBox(width: 4),

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

  // ── Perfil Declarado do Usuário ───────────────────────────
  Widget _buildUserProfileBadge() {
    String ageText;
    switch (_ageGroup) {
      case 'under_20':
        ageText = '< 20 anos';
        break;
      case '36_50':
        ageText = '36-50 anos';
        break;
      case '50_plus':
        ageText = '50+ anos';
        break;
      case '20_35':
      default:
        ageText = '20-35 anos';
        break;
    }

    String outdoorText;
    switch (_outdoorExposure) {
      case 'outdoor_high':
        outdoorText = '☀️ Sol & Esporte Frequente';
        break;
      case 'outdoor_low':
        outdoorText = '💻 Home Office / Pouco Sol';
        break;
      case 'outdoor_moderate':
      default:
        outdoorText = '🚴 Sol Moderado';
        break;
    }

    return InkWell(
      onTap: () => _showEditProfileModal(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1712),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC8714A).withAlpha(45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.tune, color: Color(0xFFE8C9A0), size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Perfil: $ageText • $outdoorText${_profile.note.isEmpty && _profile.avoidIngredients.isEmpty && _profile.conditions.isEmpty ? '' : ' • com restrições'}',
                style: const TextStyle(
                  color: Color(0xFFE8C9A0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Text(
              'Ajustar',
              style: TextStyle(
                color: Color(0xFFC8714A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 450.ms);
  }

  void _showEditProfileModal(BuildContext context) {
    String tempAge = _ageGroup ?? '20_35';
    String tempOutdoor = _outdoorExposure ?? 'outdoor_moderate';
    final tempAvoid = _profile.avoidIngredients.toSet();
    final tempConditions = _profile.conditions.toSet();
    final noteCtrl = TextEditingController(text: _profile.note);

    showModalBottomSheet(
      isDismissible: true,
      context: context,
      backgroundColor: const Color(0xFF16120E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3026),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Perfil e Hábitos de Sol',
                    style: TextStyle(
                      color: Color(0xFFF5F0EC),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Personaliza a análise do Gemini e a escolha do protetor solar ideal.',
                    style: TextStyle(
                      color: Color(0xFF8A7A6E),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Faixa Etária',
                    style: TextStyle(
                      color: Color(0xFFE8C9A0),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(
                        label: '< 20 anos',
                        selected: tempAge == 'under_20',
                        onTap: () => setModalState(() => tempAge = 'under_20'),
                      ),
                      _buildChip(
                        label: '20 a 35 anos',
                        selected: tempAge == '20_35',
                        onTap: () => setModalState(() => tempAge = '20_35'),
                      ),
                      _buildChip(
                        label: '36 a 50 anos',
                        selected: tempAge == '36_50',
                        onTap: () => setModalState(() => tempAge = '36_50'),
                      ),
                      _buildChip(
                        label: 'Mais de 50 anos',
                        selected: tempAge == '50_plus',
                        onTap: () => setModalState(() => tempAge = '50_plus'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Exposição Solar & Esportes ao Ar Livre',
                    style: TextStyle(
                      color: Color(0xFFE8C9A0),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      _buildRadioTile(
                        icon: '☀️',
                        title: 'Alta exposição solar',
                        subtitle: 'Esportes ao ar livre, praia ou sol forte frequente',
                        selected: tempOutdoor == 'outdoor_high',
                        onTap: () => setModalState(() => tempOutdoor = 'outdoor_high'),
                      ),
                      const SizedBox(height: 8),
                      _buildRadioTile(
                        icon: '🚴',
                        title: 'Exposição moderada',
                        subtitle: 'Finais de semana, lazer e trajetos urbanos',
                        selected: tempOutdoor == 'outdoor_moderate',
                        onTap: () => setModalState(() => tempOutdoor = 'outdoor_moderate'),
                      ),
                      const SizedBox(height: 8),
                      _buildRadioTile(
                        icon: '💻',
                        title: 'Baixa exposição solar',
                        subtitle: 'Rotina em ambientes fechados / home office',
                        selected: tempOutdoor == 'outdoor_low',
                        onTap: () => setModalState(() => tempOutdoor = 'outdoor_low'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_config != null)
                    AvoidanceFields(
                      config: _config!,
                      avoid: tempAvoid,
                      conditions: tempConditions,
                      note: noteCtrl,
                      onChanged: (fn) => setModalState(fn),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        await UserProfileStore.save(_profile.copyWith(
                          ageGroup: tempAge,
                          outdoorExposure: tempOutdoor,
                          avoidIngredients: tempAvoid.toList(),
                          conditions: tempConditions.toList(),
                          note: noteCtrl.text.trim(),
                        ));
                        if (mounted && ctx.mounted) {
                          Navigator.pop(ctx);
                          _loadDashboardData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC8714A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Salvar Preferências',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(noteCtrl.dispose);
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC8714A) : const Color(0xFF221A14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFFE8A44A) : const Color(0xFF3A3026),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFFD6C8BC),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRadioTile({
    required String icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF261C14) : const Color(0xFF1C1712),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFC8714A) : const Color(0xFF2E241C),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? const Color(0xFFF5F0EC) : const Color(0xFFD6C8BC),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8A7A6E),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? const Color(0xFFC8714A) : const Color(0xFF4A3C30),
              size: 20,
            ),
          ],
        ),
      ),
    );
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
                    Text(
                      _config?.texts.dashboardSunTitle ?? AppTexts.fallback.dashboardSunTitle,
                      style: const TextStyle(
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
                Text(
                  _config?.texts.dashboardSunBody ?? AppTexts.fallback.dashboardSunBody,
                  style: const TextStyle(
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
                    'Comece sua Análise Visual',
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
                label: 'Indicador Geral',
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
    final completedCount = currentChecked.length;

    final avoided = _config == null ? _profile.avoidIngredients.toSet() : _profile.avoidedIds(_config!);
    final morningSource = _config?.morning ?? const <RoutineStepConfig>[];
    final nightSource = _config?.night ?? const <RoutineStepConfig>[];
    final morningSteps = morningSource.isEmpty
        ? [
            ('🧴', 'Limpeza Facial', 'Gel de limpeza suave'),
            ('💧', 'Sérum de Tratamento', 'Sérum leve compatível com o seu perfil'),
            ('☀️', 'Protetor Solar FPS 50+', 'Toque seco. Não pule este passo!'),
          ]
        : [
            for (final step in morningSource) (step.emoji, step.title, step.textFor(avoided)),
          ];
    final nightSteps = nightSource.isEmpty
        ? [
            ('🧼', 'Limpeza', 'Remoção do protetor solar e da poluição'),
            ('✨', 'Tratamento Noturno', 'Ativo suave compatível com o seu perfil'),
            ('💦', 'Hidratação Leve', 'Gel facial que não pesa no calor'),
          ]
        : [
            for (final step in nightSource) (step.emoji, step.title, step.textFor(avoided)),
          ];

    final activeSteps = _isMorningTab ? morningSteps : nightSteps;
    final totalSteps = activeSteps.length;

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
                  _quotaStatus?.statusText ?? 'Análise visual cosmética por IA',
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
