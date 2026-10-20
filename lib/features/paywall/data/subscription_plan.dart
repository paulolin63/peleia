// ============================================================
//  lib/features/paywall/data/subscription_plan.dart
//
//  Modelos de planos + lógica de negócio
// ============================================================

enum PlanInterval { weekly, monthly, annual }

class SubscriptionPlan {
  final PlanInterval interval;
  final String productId;       // ID no Google Play Console
  final String label;           // "Semanal", "Mensal", "Anual"
  final double price;           // Em R$
  final String? savings;        // "Economize R$ 149/ano"
  final String badge;           // "" ou "MAIS POPULAR"
  final bool hasTrial;          // Tem 3 dias grátis?

  const SubscriptionPlan({
    required this.interval,
    required this.productId,
    required this.label,
    required this.price,
    this.savings,
    this.badge = '',
    this.hasTrial = false,
  });

  // Preço formatado: "R$ 9,90"
  String get priceFormatted =>
      'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';

  // Período em texto: "/semana", "/mês", "/ano"
  String get periodLabel {
    switch (interval) {
      case PlanInterval.weekly:
        return '/ semana';
      case PlanInterval.monthly:
        return '/ mês';
      case PlanInterval.annual:
        return '/ ano';
    }
  }

  // Equivalente mensal para o plano anual
  String get monthlyEquivalent {
    if (interval != PlanInterval.annual) return '';
    final monthly = price / 12;
    return 'R\$ ${monthly.toStringAsFixed(2).replaceAll('.', ',')} / mês';
  }

  bool get isHighlighted => interval == PlanInterval.monthly;
  bool get isBestValue => interval == PlanInterval.annual;
}

// Catálogo de planos — deve espelhar o Google Play Console
const kPlans = [
  SubscriptionPlan(
    interval: PlanInterval.weekly,
    productId: 'peleia_weekly_990',
    label: 'Semanal',
    price: 9.90,
    badge: '',
    hasTrial: false,
  ),
  SubscriptionPlan(
    interval: PlanInterval.monthly,
    productId: 'peleia_monthly_1990',
    label: 'Mensal',
    price: 19.90,
    badge: '⭐ MAIS POPULAR',
    hasTrial: true,   // 3 dias grátis no mensal
  ),
  SubscriptionPlan(
    interval: PlanInterval.annual,
    productId: 'peleia_annual_8990',
    label: 'Anual',
    price: 89.90,
    savings: 'Economize R\$ 149 💚',
    badge: '',
    hasTrial: false,
  ),
];
