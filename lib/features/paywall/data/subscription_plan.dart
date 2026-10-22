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
  });

  bool get hasTrial => false;
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
      plans.add(SubscriptionPlan(
        productId: plan.productId,
        label: plan.label,
        badge: plan.badge,
        quotaSubtitle: plan.subtitle,
        priceLabel: product?.priceString ?? '',
        periodLabel: plan.consumable ? 'único' : _period(product),
        isConsumable: plan.consumable,
        isHighlighted: plan.highlight,
        isBestValue: !plan.consumable && !plan.highlight && plan.productId.contains('annual'),
      ));
    }
    return plans;
  }

  static String _period(StoreProduct? product) {
    final id = product?.identifier ?? '';
    if (id.contains('annual')) return '/ ano';
    if (id.contains('month')) return '/ mês';
    return '';
  }
}
