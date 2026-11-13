// Paywall: pick plan + subscribe. No feature marketing wall.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'paywall_provider.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  final bool isModal;
  final bool preferSos;
  const PaywallScreen({super.key, this.isModal = false, this.preferSos = false});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _appliedSosPref = false;

  void _close() {
    if (widget.isModal) {
      Navigator.of(context).pop();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paywallProvider);

    if (widget.preferSos && !_appliedSosPref && state.plans.isNotEmpty) {
      _appliedSosPref = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sos = state.plans.where((p) => p.isConsumable);
        if (sos.isNotEmpty) {
          ref.read(paywallProvider.notifier).selectPlan(sos.first.productId);
        }
      });
    }

    ref.listen<PaywallState>(paywallProvider, (_, next) {
      if (next.step == PurchaseStep.success ||
          next.step == PurchaseStep.restored) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!context.mounted) return;
          if (widget.isModal) {
            Navigator.of(context).pop(true);
          } else {
            context.go('/');
          }
        });
      }
    });

    if (state.step == PurchaseStep.success ||
        state.step == PurchaseStep.restored) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: Text(
            'Pronto.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      );
    }

    final selected = state.selectedProductId;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close, size: 22),
                    color: AppTheme.textSecondary,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () => ref
                            .read(paywallProvider.notifier)
                            .restorePurchases(),
                    child: const Text(
                      'Restaurar',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Premium',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 28),
              if (state.isLoadingPackages)
                const Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: state.plans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final plan = state.plans[i];
                      final isSelected = plan.productId == selected ||
                          (selected.isEmpty && i == 0);
                      return InkWell(
                        onTap: () => ref
                            .read(paywallProvider.notifier)
                            .selectPlan(plan.productId),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.textPrimary
                                  : AppTheme.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plan.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    if (plan.priceLabel.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${plan.priceLabel}${plan.periodLabel.isEmpty ? '' : ' / ${plan.periodLabel}'}',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: AppTheme.textPrimary,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: state.isLoading
                      ? null
                      : () => ref.read(paywallProvider.notifier).purchase(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.textPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: state.step == PurchaseStep.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Assinar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
