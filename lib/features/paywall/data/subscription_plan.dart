// ============================================================
//  lib/features/paywall/data/subscription_plan.dart
//
//  Modelos de planos + lógica de negócio
// ============================================================

enum PlanInterval { monthly, annual, sosPack }

class SubscriptionPlan {
  final PlanInterval interval;
  final String productId;       // ID no Google Play Console
  final String label;           // "Mensal", "Anual", "Pacote SOS"
  final double price;           // Em R$
  final String? savings;        // "Economize R$ 149/ano"
  final String badge;           // "" ou "MAIS POPULAR"
  final bool hasTrial;          // Tem 3 dias grátis?
  final String quotaSubtitle;   // Limite de uso claro
  final bool isConsumable;      // Produto avulso (não recorrente)

  const SubscriptionPlan({
    required this.interval,
    required this.productId,
    required this.label,
    required this.price,
    required this.quotaSubtitle,
    this.savings,
    this.badge = '',
    this.hasTrial = false,
    this.isConsumable = false,
  });

  // Preço formatado: "R$ 9,90"
  String get priceFormatted =>
      'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';

  String get periodLabel {
    switch (interval) {
      case PlanInterval.monthly:
        return '/ mês';
      case PlanInterval.annual:
        return '/ ano';
      case PlanInterval.sosPack:
        return 'único';
    }
  }

  String get monthlyEquivalent {
    if (interval != PlanInterval.annual) return '';
    final monthly = price / 12;
    return 'R\$ ${monthly.toStringAsFixed(2).replaceAll('.', ',')} / mês';
  }

  bool get isHighlighted => interval == PlanInterval.monthly;
  bool get isBestValue => interval == PlanInterval.annual;
}

// Catálogo de planos — Google Play Console
const kPlans = [
  SubscriptionPlan(
    interval: PlanInterval.monthly,
    productId: 'peleia_monthly_1990',
    label: 'Pro Mensal',
    price: 19.90,
    badge: '⭐ MAIS POPULAR',
    quotaSubtitle: 'Até 2 análises por dia (60/mês)',
    hasTrial: true,   // 3 dias grátis no mensal
    isConsumable: false,
  ),
  SubscriptionPlan(
    interval: PlanInterval.annual,
    productId: 'peleia_annual_8990',
    label: 'Pro Anual',
    price: 89.90,
    savings: 'Economize R\$ 149 💚',
    quotaSubtitle: 'Até 2 análises por dia (730/ano)',
    badge: 'MELHOR VALOR',
    hasTrial: false,
    isConsumable: false,
  ),
  SubscriptionPlan(
    interval: PlanInterval.sosPack,
    productId: 'peleia_sos_690',
    label: 'Pacote SOS (3 Análises)',
    price: 6.90,
    quotaSubtitle: '3 análises avulsas • sem assinatura',
    badge: 'PAGAMENTO ÚNICO',
    hasTrial: false,
    isConsumable: true,
  ),
];
