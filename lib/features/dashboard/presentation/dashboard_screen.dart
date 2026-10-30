// ============================================================
//  lib/features/dashboard/presentation/dashboard_screen.dart
//
//  Painel Diário de Skincare (Dashboard)
//  - Saudação personalizada e status da pele
//  - Alerta UV e clima brasileiro do dia
//  - Checklist diário de rotina (Manhã e Noite com checkboxes)
//  - Atalhos para Nova Análise, Evolução Antes & Depois e Premium
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/localization/app_translations.dart';
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
  bool _showStreakConfetti = false;
  int _confettiKey = 0;

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

    final prevChecked = isMorning ? _morningChecked : _nightChecked;
    final totalSteps = (isMorning
        ? (_config?.morning.isNotEmpty == true ? _config!.morning.length : 3)
        : (_config?.night.isNotEmpty == true ? _config!.night.length : 3));
    final wasComplete = totalSteps > 0 && prevChecked.length >= totalSteps;

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

    final currentChecked = isMorning ? _morningChecked : _nightChecked;
    final nowComplete = totalSteps > 0 && currentChecked.length >= totalSteps;

    if (!wasComplete && nowComplete) {
      HapticFeedback.mediumImpact();
      setState(() {
        _showStreakConfetti = true;
        _confettiKey++;
      });
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _showStreakConfetti = false);
      });
    } else {
      HapticFeedback.lightImpact();
    }
  }

  String _getGreeting(AppTranslations tr) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return tr.dashGreetingMorning;
    if (hour >= 12 && hour < 18) return tr.dashGreetingAfternoon;
    return tr.dashGreetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);

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
      body: Stack(
        children: [
          SafeArea(
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
                        _buildTopHeader(tr),

                        const SizedBox(height: 12),

                        // ── Perfil Declarado do Usuário ─────────────
                        _buildUserProfileBadge(tr),

                        const SizedBox(height: 16),

                        // ── Card de Alerta UV e Clima BR ────────────
                        _buildUvAlertCard(tr),

                        const SizedBox(height: 18),

                        // ── Card de Status da Pele / Última Análise ─
                        _buildSkinStatusCard(tr),

                        const SizedBox(height: 22),

                        // ── Checklist da Rotina de Hoje ─────────────
                        _buildDailyRoutineSection(tr),

                        const SizedBox(height: 24),

                        // ── Botão Principal: Nova Análise com IA ────
                        _buildScanCTA(tr),

                        const SizedBox(height: 16),

                        // ── Atalhos Rápidos (Evolução & Premium) ─────
                        _buildQuickActionCards(tr),

                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showStreakConfetti)
            Positioned.fill(
              child: IgnorePointer(
                child: _TerracottaConfetti(key: ValueKey(_confettiKey)),
              ),
            ),
        ],
      ),
    );
  }

  // ── 1. Header Superior com Saudação e Badges ──────────────
  Widget _buildTopHeader(AppTranslations tr) {
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
              '${_getGreeting(tr)}${tr.dashGreetingSuffix}',
              style: const TextStyle(
                color: Color(0xFF8A7A6E),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              tr.dashDailyHeader,
              style: const TextStyle(
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
                Text(_isPro ? tr.dashProBadge : tr.dashSubscribeBtn,
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
  Widget _buildUserProfileBadge(AppTranslations tr) {
    String ageText;
    switch (_ageGroup) {
      case 'under_20':
        ageText = tr.isEn ? '< 20 yrs' : '< 20 anos';
        break;
      case '36_50':
        ageText = tr.isEn ? '36-50 yrs' : '36-50 anos';
        break;
      case '50_plus':
        ageText = tr.isEn ? '50+ yrs' : '50+ anos';
        break;
      case '20_35':
      default:
        ageText = tr.isEn ? '20-35 yrs' : '20-35 anos';
        break;
    }

    String outdoorText;
    switch (_outdoorExposure) {
      case 'outdoor_high':
        outdoorText = tr.isEn ? '☀️ Frequent Sun & Sports' : '☀️ Sol & Esporte Frequente';
        break;
      case 'outdoor_low':
        outdoorText = tr.isEn ? '💻 Home Office / Low Sun' : '💻 Home Office / Pouco Sol';
        break;
      case 'outdoor_moderate':
      default:
        outdoorText = tr.isEn ? '🚴 Moderate Sun' : '🚴 Sol Moderado';
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
                '${tr.dashProfilePrefix} $ageText • $outdoorText${_profile.note.isEmpty && _profile.avoidIngredients.isEmpty && _profile.conditions.isEmpty ? '' : ' • ${tr.dashWithRestrictions}'}',
                style: const TextStyle(
                  color: Color(0xFFE8C9A0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              tr.dashAdjustProfile,
              style: const TextStyle(
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
  Widget _buildUvAlertCard(AppTranslations tr) {
    final title = tr.isEn ? tr.dashSunTitle : (_config?.texts.dashboardSunTitle ?? AppTexts.fallback.dashboardSunTitle);
    final body = tr.isEn ? tr.dashSunDesc : (_config?.texts.dashboardSunBody ?? AppTexts.fallback.dashboardSunBody);

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
                      title,
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
                  body,
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
  Widget _buildSkinStatusCard(AppTranslations tr) {
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr.dashNewUserTitle,
                    style: const TextStyle(
                      color: Color(0xFFF5F0EC),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tr.dashNewUserDesc,
                    style: const TextStyle(color: Color(0xFF8A7A6E), fontSize: 12, height: 1.4),
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
                '${tr.dashCurrentSkinPrefix}${tr.translateSkinType(_latestEntry!.skinType)}',
                style: const TextStyle(
                  color: Color(0xFFF5F0EC),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                _latestEntry!.formattedDate,
                style: const TextStyle(color: Color(0xFF8A7A6E), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniMetric(
                label: tr.dashIndicatorGeneral,
                value: '${_latestEntry!.scoreGeral}',
                suffix: 'pts',
                color: const Color(0xFF6AB187),
              ),
              _buildMiniMetric(
                label: tr.dashOiliness,
                value: '${_latestEntry!.oleosidade}',
                suffix: '/10',
                color: const Color(0xFFE8A44A),
              ),
              _buildMiniMetric(
                label: tr.dashAcne,
                value: '${_latestEntry!.acne}',
                suffix: '/10',
                color: const Color(0xFFD96B6B),
              ),
              _buildMiniMetric(
                label: tr.dashSpots,
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
  Widget _buildDailyRoutineSection(AppTranslations tr) {
    final currentChecked = _isMorningTab ? _morningChecked : _nightChecked;
    final completedCount = currentChecked.length;

    final avoided = _config == null ? _profile.avoidIngredients.toSet() : _profile.avoidedIds(_config!);
    final morningSource = _config?.morning ?? const <RoutineStepConfig>[];
    final nightSource = _config?.night ?? const <RoutineStepConfig>[];
    final morningSteps = morningSource.isEmpty
        ? [
            ('🧴', tr.isEn ? 'Facial Cleansing' : 'Limpeza Facial', tr.isEn ? 'Gentle cleansing gel' : 'Gel de limpeza suave'),
            ('💧', tr.isEn ? 'Treatment Serum' : 'Sérum de Tratamento', tr.isEn ? 'Lightweight serum compatible with your skin' : 'Sérum leve compatível com o seu perfil'),
            ('☀️', tr.isEn ? 'SPF 50+ Sunscreen' : 'Protetor Solar FPS 50+', tr.isEn ? 'Dry touch. Do not skip this step!' : 'Toque seco. Não pule este passo!'),
          ]
        : [
            for (final step in morningSource) (step.emoji, step.title, step.textFor(avoided)),
          ];
    final nightSteps = nightSource.isEmpty
        ? [
            ('🧼', tr.isEn ? 'Cleansing' : 'Limpeza', tr.isEn ? 'Removal of sunscreen & impurities' : 'Remoção do protetor solar e da poluição'),
            ('✨', tr.isEn ? 'Night Treatment' : 'Tratamento Noturno', tr.isEn ? 'Gentle active suited to your skin' : 'Ativo suave compatível com o seu perfil'),
            ('💦', tr.isEn ? 'Light Moisturizer' : 'Hidratação Leve', tr.isEn ? 'Facial gel that feels weightless in the heat' : 'Gel facial que não pesa no calor'),
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
              Text(
                tr.dashTodayRoutine,
                style: const TextStyle(
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
                    _buildRoutineToggle(tr.dashMorning, _isMorningTab, () {
                      setState(() => _isMorningTab = true);
                    }),
                    _buildRoutineToggle(tr.dashNight, !_isMorningTab, () {
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
                tr.dashStepsCompleted(completedCount, totalSteps),
                style: const TextStyle(color: Color(0xFFE8C9A0), fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (completedCount == totalSteps)
                Text(tr.dashAllDone, style: const TextStyle(color: Color(0xFF6AB187), fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0.0,
                end: totalSteps > 0 ? completedCount / totalSteps : 0.0,
              ),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, val, _) {
                return LinearProgressIndicator(
                  value: val,
                  backgroundColor: Colors.white.withAlpha(12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    val >= 1.0 ? const Color(0xFF6AB187) : const Color(0xFFC8714A),
                  ),
                  minHeight: 7,
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Lista interativa de passos com bounce no check
          ...activeSteps.asMap().entries.map((entry) {
            final idx = entry.key;
            final (emoji, title, desc) = entry.value;
            final isChecked = currentChecked.contains(idx);

            return GestureDetector(
              onTap: () => _toggleStep(idx, _isMorningTab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
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
                    AnimatedScale(
                      scale: isChecked ? 1.05 : 0.95,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.elasticOut,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                          key: ValueKey<bool>(isChecked),
                          color: isChecked ? const Color(0xFF6AB187) : const Color(0xFF8A7A6E),
                          size: 22,
                        ),
                      ),
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
  Widget _buildScanCTA(AppTranslations tr) {
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
                Text(
                  tr.dashScanCTA,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _quotaStatus?.statusText ?? tr.dashScanCTAHint,
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
  Widget _buildQuickActionCards(AppTranslations tr) {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📈', style: TextStyle(fontSize: 22)),
                  const SizedBox(height: 8),
                  Text(
                    tr.dashEvolutionTitle,
                    style: const TextStyle(
                      color: Color(0xFFF5F0EC),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr.dashEvolutionDesc,
                    style: const TextStyle(color: Color(0xFF8A7A6E), fontSize: 11),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 22)),
                  const SizedBox(height: 8),
                  Text(
                    tr.dashProTitle,
                    style: const TextStyle(
                      color: Color(0xFFF5F0EC),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr.dashProDesc,
                    style: const TextStyle(color: Color(0xFF8A7A6E), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 550.ms);
  }
}

// ── Confetti leve de streak (partículas terracota curtas, sem emoji spam) ──
class _TerracottaConfetti extends StatefulWidget {
  const _TerracottaConfetti({super.key});

  @override
  State<_TerracottaConfetti> createState() => _TerracottaConfettiState();
}

class _TerracottaConfettiState extends State<_TerracottaConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    final rnd = math.Random();
    const colors = [
      Color(0xFFC8714A), // Terracota principal
      Color(0xFFE8A44A), // Dourado quente
      Color(0xFF6AB187), // Sálvia
      Color(0xFFF2A58B), // Pêssego suave
      Color(0xFFFFF0E8), // Pérola
    ];

    _particles = List.generate(24, (i) {
      final angle = (rnd.nextDouble() * 2 * math.pi);
      final speed = 120.0 + rnd.nextDouble() * 220.0;
      final size = 4.0 + rnd.nextDouble() * 5.0;
      final color = colors[i % colors.length];
      final isCircle = rnd.nextBool();
      return _ConfettiParticle(
        angle: angle,
        speed: speed,
        size: size,
        color: color,
        isCircle: isCircle,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final progress = _ctrl.value;
        final opacity = (1.0 - progress).clamp(0.0, 1.0);
        return CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            particles: _particles,
            progress: progress,
            opacity: opacity,
          ),
        );
      },
    );
  }
}

class _ConfettiParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final bool isCircle;

  const _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.isCircle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  final double opacity;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.45);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final dist = p.speed * progress * (1.0 - progress * 0.3);
      final dx = center.dx + math.cos(p.angle) * dist;
      // Adiciona gravidade suave puxando para baixo
      final dy = center.dy + math.sin(p.angle) * dist + (progress * progress * 90);

      paint.color = p.color.withAlpha((opacity * 0.9 * 255).round());

      if (p.isCircle) {
        canvas.drawCircle(Offset(dx, dy), p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(dx, dy), width: p.size * 1.5, height: p.size * 0.7),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress || old.opacity != opacity;
}
