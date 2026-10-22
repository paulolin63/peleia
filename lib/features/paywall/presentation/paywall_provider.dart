// ============================================================
//  lib/features/paywall/presentation/paywall_provider.dart
//
//  Estado e lógica da tela de assinatura
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/remote_config_service.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../../core/services/quota_service.dart';
import '../data/subscription_plan.dart';

// ── Estado ───────────────────────────────────────────────
enum PurchaseStep { idle, loading, success, error, restored }

class PaywallState {
  final PurchaseStep step;
  final String selectedProductId;
  final bool isPremium;
  final bool isLoadingPackages;
  final List<Package> packages;
  final List<SubscriptionPlan> plans;
  final String? errorMessage;

  const PaywallState({
    this.step = PurchaseStep.idle,
    this.selectedProductId = '',
    this.isPremium = false,
    this.isLoadingPackages = false,
    this.packages = const [],
    this.plans = const [],
    this.errorMessage,
  });

  PaywallState copyWith({
    PurchaseStep? step,
    String? selectedProductId,
    bool? isPremium,
    bool? isLoadingPackages,
    List<Package>? packages,
    List<SubscriptionPlan>? plans,
    String? errorMessage,
  }) =>
      PaywallState(
        step: step ?? this.step,
        selectedProductId: selectedProductId ?? this.selectedProductId,
        isPremium: isPremium ?? this.isPremium,
        isLoadingPackages: isLoadingPackages ?? this.isLoadingPackages,
        packages: packages ?? this.packages,
        plans: plans ?? this.plans,
        errorMessage: errorMessage,
      );

  bool get isLoading => step == PurchaseStep.loading || isLoadingPackages;
}

// ── Notifier ─────────────────────────────────────────────
class PaywallNotifier extends StateNotifier<PaywallState> {
  PaywallNotifier() : super(const PaywallState()) {
    _init();
  }

  Future<void> _init() async {
    final config = await RemoteConfigService.load();
    final premium = await RevenueCatService.isPremium();
    final prefs = await SharedPreferences.getInstance();
    if (premium) {
      await prefs.setBool('is_premium', true);
    } else if (kReleaseMode) {
      await prefs.setBool('is_premium', false);
    }

    if (kIsWeb) {
      state = state.copyWith(
        isPremium: premium,
        plans: SubscriptionPlan.fromStore(
          config: config,
          packages: const [],
          allowWithoutStore: !kReleaseMode,
        ),
      );
      _selectDefault();
      return;
    }

    state = state.copyWith(isLoadingPackages: true, isPremium: premium);
    final pkgs = await RevenueCatService.getPackages();
    state = state.copyWith(
      packages: pkgs,
      isLoadingPackages: false,
      plans: SubscriptionPlan.fromStore(
        config: config,
        packages: pkgs,
        allowWithoutStore: !kReleaseMode && pkgs.isEmpty,
      ),
    );
    _selectDefault();
  }

  void _selectDefault() {
    if (state.plans.isEmpty) return;
    final highlighted = state.plans.where((p) => p.isHighlighted);
    state = state.copyWith(
      selectedProductId: (highlighted.isEmpty ? state.plans.first : highlighted.first).productId,
    );
  }

  void selectPlan(String productId) {
    state = state.copyWith(selectedProductId: productId);
  }

  SubscriptionPlan? get _selected {
    for (final plan in state.plans) {
      if (plan.productId == state.selectedProductId) return plan;
    }
    return state.plans.isEmpty ? null : state.plans.first;
  }

  // ── Compra o plano selecionado ──────────────────────────
  Future<void> purchase() async {
    state = state.copyWith(step: PurchaseStep.loading, errorMessage: null);

    final selectedPlanData = _selected;
    if (selectedPlanData == null) {
      state = state.copyWith(
        step: PurchaseStep.error,
        errorMessage: 'Nenhum plano disponível na loja agora.',
      );
      return;
    }

    if (kIsWeb) {
      if (kReleaseMode) {
        state = state.copyWith(
          step: PurchaseStep.error,
          errorMessage: 'Assinatura disponível no aplicativo Android.',
        );
        return;
      }
      await Future.delayed(const Duration(seconds: 1));
      await _grantDebug(selectedPlanData);
      return;
    }

    try {
      final Package? package = _findPackage(selectedPlanData.productId);

      if (package == null) {
        if (kReleaseMode) {
          state = state.copyWith(
            step: PurchaseStep.error,
            errorMessage: 'Este plano não está disponível na Google Play.',
          );
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
        await _grantDebug(selectedPlanData);
        return;
      }

      final success = await RevenueCatService.purchasePackage(package);
      if (success) {
        if (selectedPlanData.isConsumable) {
          await QuotaService.addSosCredits(QuotaService.sosPackSize);
          state = state.copyWith(step: PurchaseStep.success);
        } else {
          await _savePremiumLocally();
          state = state.copyWith(step: PurchaseStep.success, isPremium: true);
        }
      } else {
        state = state.copyWith(
          step: PurchaseStep.error,
          errorMessage: 'Compra não completada. Tente novamente.',
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('cancel')) {
        state = state.copyWith(step: PurchaseStep.idle);
      } else {
        state = state.copyWith(
          step: PurchaseStep.error,
          errorMessage: 'Erro na compra: $msg',
        );
      }
    }
  }

  // ── Restaurar compras ───────────────────────────────────
  Future<void> restorePurchases() async {
    state = state.copyWith(step: PurchaseStep.loading);

    if (kIsWeb) {
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(step: PurchaseStep.idle);
      return;
    }

    final success = await RevenueCatService.restorePurchases();
    final prefs = await SharedPreferences.getInstance();
    if (success) {
      await _savePremiumLocally();
      state = state.copyWith(
        step: PurchaseStep.restored,
        isPremium: true,
      );
    } else {
      if (kReleaseMode) await prefs.setBool('is_premium', false);
      state = state.copyWith(
        step: PurchaseStep.error,
        isPremium: false,
        errorMessage: 'Nenhuma compra anterior encontrada.',
      );
    }
  }

  Future<void> _grantDebug(SubscriptionPlan plan) async {
    if (plan.isConsumable) {
      await QuotaService.addSosCredits(QuotaService.sosPackSize);
      state = state.copyWith(step: PurchaseStep.success);
    } else {
      await _savePremiumLocally();
      state = state.copyWith(step: PurchaseStep.success, isPremium: true);
    }
  }

  Package? _findPackage(String productId) {
    try {
      return state.packages.firstWhere(
        (p) => p.storeProduct.identifier == productId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePremiumLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
  }

  void dismissError() {
    state = state.copyWith(step: PurchaseStep.idle, errorMessage: null);
  }
}

// ── Provider global ──────────────────────────────────────
final paywallProvider =
    StateNotifierProvider<PaywallNotifier, PaywallState>(
  (ref) => PaywallNotifier(),
);

// ── Provider de status premium (usado em toda a app) ─────
final isPremiumProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final remote = await RevenueCatService.isPremium();
  if (remote) {
    await prefs.setBool('is_premium', true);
    return true;
  }
  if (kReleaseMode) {
    await prefs.setBool('is_premium', false);
    return false;
  }
  return prefs.getBool('is_premium') ?? false;
});
