import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/config/app_config.dart';

class SubscriptionPlan {
  final String productId;
  final String label;
  final String badge;
  final String quotaSubtitle;
  final String priceLabel;
  final String periodLabel;
  final bool isConsumable;
  final bool isHighlighted;
  final bool isBestValue;
  final bool hasTrial;
  final String? trialLabel;

  const SubscriptionPlan({
    required this.productId,
    required this.label,
    required this.badge,
    required this.quotaSubtitle,
    required this.priceLabel,
    required this.periodLabel,
    required this.isConsumable,
    required this.isHighlighted,
    required this.isBestValue,
    this.hasTrial = false,
    this.trialLabel,
  });

  String get priceFormatted => priceLabel;
  String? get savings => null;
  String get monthlyEquivalent => '';

  static List<SubscriptionPlan> fromStore({
    required AppConfig config,
    required List<Package> packages,
    required bool allowWithoutStore,
  }) {
    final plans = <SubscriptionPlan>[];
    for (final plan in config.plans) {
      Package? package;
      for (final item in packages) {
        if (item.storeProduct.identifier == plan.productId) {
          package = item;
          break;
        }
      }
      if (package == null && !allowWithoutStore) continue;
      final product = package?.storeProduct;
      final trial = _trialInfo(product);
      plans.add(SubscriptionPlan(
        productId: plan.productId,
        label: plan.label,
        badge: trial.$1 ? (trial.$2 ?? 'TESTE GRÁTIS') : plan.badge,
        quotaSubtitle: plan.subtitle,
        priceLabel: product?.priceString ?? '',
        periodLabel: plan.consumable ? 'único' : _period(product),
        isConsumable: plan.consumable,
        isHighlighted: plan.highlight,
        isBestValue: !plan.consumable && !plan.highlight && plan.productId.contains('annual'),
        hasTrial: trial.$1,
        trialLabel: trial.$2,
      ));
    }
    return plans;
  }

  static (bool, String?) _trialInfo(StoreProduct? product) {
    if (product == null) return (false, null);
    final intro = product.introductoryPrice;
    if (intro == null) return (false, null);
    final free = intro.price == 0;
    if (!free) return (false, null);
    final cycles = intro.periodNumberOfUnits;
    final unit = intro.periodUnit;
    String label;
    switch (unit) {
      case PeriodUnit.day:
        label = cycles == 1 ? '1 dia grátis' : '$cycles dias grátis';
      case PeriodUnit.week:
        label = cycles == 1 ? '1 semana grátis' : '$cycles semanas grátis';
      case PeriodUnit.month:
        label = cycles == 1 ? '1 mês grátis' : '$cycles meses grátis';
      case PeriodUnit.year:
        label = cycles == 1 ? '1 ano grátis' : '$cycles anos grátis';
      default:
        label = 'Teste grátis';
    }
    return (true, label);
  }

  static String _period(StoreProduct? product) {
    final id = product?.identifier ?? '';
    if (id.contains('annual')) return '/ ano';
    if (id.contains('month')) return '/ mês';
    return '';
  }
}
