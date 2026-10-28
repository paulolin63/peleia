// ============================================================
//  lib/features/paywall/presentation/paywall_screen.dart
//
//  Tela de assinatura Premium — RevenueCat + Google Play Billing
//  Preço exibido é o da loja. Textos e limites vêm da config remota.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/remote_config_service.dart';
import '../data/subscription_plan.dart';
import 'paywall_provider.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  /// Se true, exibe como modal (bottom sheet); se false, tela cheia
  final bool isModal;
  /// Prefers SOS consumable when opened from quota impulse CTA.
  final bool preferSos;
  const PaywallScreen({super.key, this.isModal = false, this.preferSos = false});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _appliedSosPref = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paywallProvider);
    final texts = ref.watch(appConfigProvider).valueOrNull?.texts ?? AppTexts.fallback;

    if (widget.preferSos && !_appliedSosPref && state.plans.isNotEmpty) {
      _appliedSosPref = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sos = state.plans.where((p) => p.isConsumable);
        if (sos.isNotEmpty) {
          ref.read(paywallProvider.notifier).selectPlan(sos.first.productId);
        }
      });
    }

    // Navega de volta após sucesso
    ref.listen<PaywallState>(paywallProvider, (_, next) {
      if (next.step == PurchaseStep.success ||
          next.step == PurchaseStep.restored) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (context.mounted) {
            if (widget.isModal) {
              Navigator.of(context).pop(true);
            } else {
              context.go('/');
            }
          }
        });
      }
    });

    // Tela de sucesso
    if (state.step == PurchaseStep.success ||
        state.step == PurchaseStep.restored) {
      return _SuccessOverlay(
        isRestored: state.step == PurchaseStep.restored,
        items: texts.paywallSuccessItems,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────
          SliverAppBar(
            pinned: false,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF8A7A6E)),
              onPressed: () =>
                  widget.isModal ? Navigator.pop(context) : context.go('/'),
            ),
            actions: [
              TextButton(
                onPressed: state.isLoading
                    ? null
                    : () => ref.read(paywallProvider.notifier).restorePurchases(),
                child: const Text(
                  'Restaurar',
                  style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 13),
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Hero ─────────────────────────────────────
                _buildHero(texts).animate().fadeIn(delay: 50.ms),

                const SizedBox(height: 24),

                // ── Feature list ──────────────────────────────
                _buildFeatureList(texts).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 28),

                // ── Planos de preço ───────────────────────────
                _buildPlanCards(state, ref)
                    .animate()
                    .fadeIn(delay: 250.ms)
                    .slideY(begin: 0.1),

                const SizedBox(height: 24),

                // ── CTA Button ────────────────────────────────
                _buildCTAButton(state, ref)
                    .animate()
                    .fadeIn(delay: 350.ms)
                    .slideY(begin: 0.2),

                const SizedBox(height: 14),

                // ── Fine print ────────────────────────────────
                _buildFinePrint(state).animate().fadeIn(delay: 450.ms),

                const SizedBox(height: 32),

                // ── Social proof (honest during closed testing) ─
                _buildSocialProof().animate().fadeIn(delay: 550.ms),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── HERO ─────────────────────────────────────────────────
  Widget _buildHero(AppTexts texts) {
    return Column(
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '✨ PeleIA Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          texts.paywallTitle,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Color(0xFFF5F0EC),
            height: 1.15,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 10),

        Text(
          texts.paywallSubtitle,
          style: const TextStyle(fontSize: 14, color: Color(0xFF8A7A6E)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── FEATURE LIST ─────────────────────────────────────────
  Widget _buildFeatureList(AppTexts texts) {
    final features = texts.paywallBenefits.map((b) => (b.emoji, b.title, b.desc)).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1712),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC8714A).withAlpha(50)),
      ),
      child: Column(
        children: features.asMap().entries.map((entry) {
          final i = entry.key;
          final (emoji, title, desc) = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: i < features.length - 1 ? 14 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8714A).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF5F0EC),
                        ),
                      ),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A7A6E),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle,
                    color: Color(0xFF6AB187), size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── PLAN CARDS ───────────────────────────────────────────
  Widget _buildPlanCards(PaywallState state, WidgetRef ref) {
    return Column(
      children: state.plans.asMap().entries.map((entry) {
        final plan = entry.value;
        final isSelected = state.selectedProductId == plan.productId;

        return GestureDetector(
          onTap: () =>
              ref.read(paywallProvider.notifier).selectPlan(plan.productId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: EdgeInsets.only(
              bottom: 10,
              top: plan.isHighlighted ? 4 : 0,
            ),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        const Color(0xFFC8714A).withAlpha(40),
                        const Color(0xFFE8A44A).withAlpha(20),
                      ],
                    )
                  : null,
              color: isSelected ? null : const Color(0xFF1C1712),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFC8714A)
                    : plan.isBestValue
                        ? const Color(0xFF6AB187).withAlpha(100)
                        : const Color(0xFF2C1A10),
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Radio indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFC8714A)
                                : const Color(0xFF4A3E35),
                            width: 2,
                          ),
                          color: isSelected
                              ? const Color(0xFFC8714A)
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 13)
                            : null,
                      ),

                      const SizedBox(width: 14),

                      // Label + savings
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? const Color(0xFFE8C9A0)
                                    : const Color(0xFFF5F0EC),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              plan.quotaSubtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8A7A6E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (plan.priceFormatted.isEmpty)
                              const Text(
                                'Preço na Google Play',
                                style: TextStyle(fontSize: 11, color: Color(0xFF8A7A6E)),
                              ),
                          ],
                        ),
                      ),

                      // Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            plan.priceFormatted,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? const Color(0xFFE8A44A)
                                  : const Color(0xFFF5F0EC),
                            ),
                          ),
                          Text(
                            plan.periodLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A7A6E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Badge "MAIS POPULAR"
                if (plan.badge.isNotEmpty)
                  Positioned(
                    top: -10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          plan.badge,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── CTA BUTTON ───────────────────────────────────────────
  Widget _buildCTAButton(PaywallState state, WidgetRef ref) {
    final selectedPlan = _selectedPlan(state);

    String buttonText;
    if (selectedPlan == null) {
      buttonText = 'Planos indisponíveis';
    } else if (state.isLoading) {
      buttonText = 'Processando...';
    } else if (selectedPlan.hasTrial) {
      buttonText = selectedPlan.trialLabel != null
          ? 'Começar ${selectedPlan.trialLabel}'
          : 'Começar teste grátis';
    } else if (selectedPlan.isConsumable) {
      buttonText = selectedPlan.priceFormatted.isEmpty
          ? 'Comprar ${selectedPlan.label}'
          : 'Comprar SOS por ${selectedPlan.priceFormatted}';
    } else if (selectedPlan.priceFormatted.isEmpty) {
      buttonText = 'Assinar ${selectedPlan.label}';
    } else {
      buttonText = 'Assinar ${selectedPlan.label} por ${selectedPlan.priceFormatted}';
    }

    return Column(
      children: [
        // Erro
        if (state.errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD96B6B).withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD96B6B).withAlpha(75)),
            ),
            child: Row(
              children: [
                const Text('❌ ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(
                        color: Color(0xFFD96B6B), fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      ref.read(paywallProvider.notifier).dismissError(),
                  child: const Icon(Icons.close,
                      color: Color(0xFFD96B6B), size: 16),
                ),
              ],
            ),
          ),

        // Botão principal
        GestureDetector(
          onTap: state.isLoading
              ? null
              : () => ref.read(paywallProvider.notifier).purchase(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 60,
            decoration: BoxDecoration(
              gradient: state.isLoading
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
                    ),
              color: state.isLoading ? const Color(0xFF2C1A10) : null,
              borderRadius: BorderRadius.circular(18),
              boxShadow: state.isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFFC8714A).withAlpha(100),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Center(
              child: state.isLoading
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        color: Color(0xFFC8714A),
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ── FINE PRINT ───────────────────────────────────────────
  Widget _buildFinePrint(PaywallState state) {
    if (state.plans.isEmpty) {
      return const Text(
        'Os planos aparecem aqui com o preço da Google Play quando a loja está disponível.',
        style: TextStyle(fontSize: 11, color: Color(0xFF8A7A6E), height: 1.5),
        textAlign: TextAlign.center,
      );
    }
    final selectedPlan = _selectedPlan(state)!;
    final price = selectedPlan.priceFormatted.isEmpty ? 'o valor exibido na Google Play' : selectedPlan.priceFormatted;
    final period = selectedPlan.periodLabel.replaceAll('/ ', '');
    final finePrintText = selectedPlan.isConsumable
        ? '$price, pagamento único, via Google Play.'
        : '$price${period.isEmpty ? '' : '/$period'} cobrado via Google Play. Cancele quando quiser.';

    return Column(
      children: [
        Text(
          finePrintText,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF4A3E35),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Trust badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _TrustBadge(emoji: '🔒', label: 'Google Play'),
            SizedBox(width: 16),
            _TrustBadge(emoji: '💳', label: 'PIX aceito'),
            SizedBox(width: 16),
            _TrustBadge(emoji: '↩️', label: 'Cancele fácil'),
          ],
        ),
      ],
    );
  }

  // ── SOCIAL PROOF ─────────────────────────────────────────
  // Honest during closed testing: no fake ratings. Swap to real
  // testimonials via remote config when you have them.
  Widget _buildSocialProof() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1712),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C1A10)),
      ),
      child: const Column(
        children: [
          Text(
            'Feito para o clima e a pele do Brasil',
            style: TextStyle(
              color: Color(0xFFE8C9A0),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Text(
            'Cobrança segura via Google Play · Cancele quando quiser · Fotos ficam no seu aparelho',
            style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 12, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── AUXILIARES ───────────────────────────────────────────
class _TrustBadge extends StatelessWidget {
  final String emoji;
  final String label;
  const _TrustBadge({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF4A3E35)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  TELA DE SUCESSO
// ══════════════════════════════════════════════════════════
SubscriptionPlan? _selectedPlan(PaywallState state) {
  for (final plan in state.plans) {
    if (plan.productId == state.selectedProductId) return plan;
  }
  return state.plans.isEmpty ? null : state.plans.first;
}

class _SuccessOverlay extends StatelessWidget {
  final bool isRestored;
  final List<String> items;
  const _SuccessOverlay({required this.isRestored, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 72))
                  .animate()
                  .scale(
                    begin: const Offset(0.3, 0.3),
                    curve: Curves.elasticOut,
                    duration: 800.ms,
                  ),

              const SizedBox(height: 24),

              Text(
                isRestored ? 'Compra restaurada!' : 'Bem-vinda ao Premium! ✨',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF5F0EC),
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 12),

              const Text(
                'Você agora tem acesso completo a todas\nas funcionalidades do PeleIA Premium.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8A7A6E),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6AB187),
                      Color(0xFF4A9268),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      Text(items[i], style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),

              const SizedBox(height: 24),

              const Text(
                'Redirecionando para o app...',
                style: TextStyle(fontSize: 12, color: Color(0xFF4A3E35)),
              ).animate().fadeIn(delay: 900.ms),
            ],
          ),
        ),
      ),
    );
  }
}
