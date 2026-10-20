// ============================================================
//  lib/features/paywall/presentation/paywall_provider.dart
//
//  Estado e lógica da tela de assinatura
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/revenuecat_service.dart';
import '../../../core/services/quota_service.dart';
import '../data/subscription_plan.dart';

// ── Estado ───────────────────────────────────────────────
enum PurchaseStep { idle, loading, success, error, restored }

class PaywallState {
  final PurchaseStep step;
  final PlanInterval selectedPlan;
  final bool isPremium;
  final bool isLoadingPackages;
  final List<Package> packages;      // Pacotes reais do RevenueCat
  final String? errorMessage;

  const PaywallState({
    this.step = PurchaseStep.idle,
    this.selectedPlan = PlanInterval.monthly, // Mensal pré-selecionado
    this.isPremium = false,
    this.isLoadingPackages = false,
    this.packages = const [],
    this.errorMessage,
  });

  PaywallState copyWith({
    PurchaseStep? step,
    PlanInterval? selectedPlan,
    bool? isPremium,
    bool? isLoadingPackages,
    List<Package>? packages,
    String? errorMessage,
  }) =>
      PaywallState(
        step: step ?? this.step,
        selectedPlan: selectedPlan ?? this.selectedPlan,
        isPremium: isPremium ?? this.isPremium,
        isLoadingPackages: isLoadingPackages ?? this.isLoadingPackages,
        packages: packages ?? this.packages,
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
    // Verifica se já é premium
    final premium = await RevenueCatService.isPremium();
    if (premium) {
      state = state.copyWith(isPremium: true);
      return;
    }

    // Carrega pacotes do RevenueCat (no web retorna vazio — simulado)
    if (!kIsWeb) {
      state = state.copyWith(isLoadingPackages: true);
      final pkgs = await RevenueCatService.getPackages();
      state = state.copyWith(
        packages: pkgs,
        isLoadingPackages: false,
      );
    }
  }

  void selectPlan(PlanInterval plan) {
    state = state.copyWith(selectedPlan: plan);
  }

  // ── Compra o plano selecionado ──────────────────────────
  Future<void> purchase() async {
    state = state.copyWith(step: PurchaseStep.loading, errorMessage: null);

    final selectedPlanData = kPlans.firstWhere(
      (p) => p.interval == state.selectedPlan,
    );

    // Web / Modo Simulação
    if (kIsWeb) {
      await Future.delayed(const Duration(seconds: 1));
      if (selectedPlanData.isConsumable) {
        await QuotaService.addSosCredits(3);
        state = state.copyWith(step: PurchaseStep.success);
      } else {
        await _savePremiumLocally();
        state = state.copyWith(step: PurchaseStep.success, isPremium: true);
      }
      return;
    }

    try {
      final Package? package = _findPackage(selectedPlanData.productId);

      if (package == null) {
        // Fallback: dev mode
        await Future.delayed(const Duration(seconds: 1));
        if (selectedPlanData.isConsumable) {
          await QuotaService.addSosCredits(3);
          state = state.copyWith(step: PurchaseStep.success);
        } else {
          await _savePremiumLocally();
          state = state.copyWith(step: PurchaseStep.success, isPremium: true);
        }
        return;
      }

      final success = await RevenueCatService.purchasePackage(package);
      if (success) {
        if (selectedPlanData.isConsumable) {
          await QuotaService.addSosCredits(3);
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
    if (success) {
      await _savePremiumLocally();
      state = state.copyWith(
        step: PurchaseStep.restored,
        isPremium: true,
      );
    } else {
      state = state.copyWith(
        step: PurchaseStep.error,
        errorMessage: 'Nenhuma compra anterior encontrada.',
      );
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
  // Verifica local primeiro (offline-first)
  final local = prefs.getBool('is_premium') ?? false;
  if (local) return true;
  // Depois verifica RevenueCat
  return RevenueCatService.isPremium();
});
