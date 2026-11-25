import 'package:flutter_test/flutter_test.dart';
import 'package:peleia/core/config/app_config.dart';
import 'package:peleia/features/paywall/data/subscription_plan.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  test('matchesProductId aceita ID exato e formato Google Play Base Plan', () {
    expect(SubscriptionPlan.matchesProductId('peleia_sos_690', 'peleia_sos_690'), isTrue);
    expect(SubscriptionPlan.matchesProductId('peleia_monthly_1990:monthly', 'peleia_monthly_1990'), isTrue);
    expect(SubscriptionPlan.matchesProductId('peleia_annual_8990:annual', 'peleia_annual_8990'), isTrue);
    expect(SubscriptionPlan.matchesProductId('peleia_sos_690:sos', 'peleia_sos_690'), isTrue);

    expect(SubscriptionPlan.matchesProductId('peleia_monthly_1990_extra', 'peleia_monthly_1990'), isFalse);
    expect(SubscriptionPlan.matchesProductId('other:monthly', 'peleia_monthly_1990'), isFalse);
  });

  test('fromStore resolve produtos diretos com Base Plan ID mesmo com Offerings vazio', () {
    final config = AppConfig.tryParse({
      'schema_version': 1,
      'config_version': 'test',
      'quota': {'free_lifetime': 1, 'pro_daily': 2, 'sos_credits': 3},
      'plans': [
        {
          'product_id': 'peleia_monthly_1990',
          'label': 'Pro Mensal',
          'badge': 'MAIS POPULAR',
          'subtitle': 'Mensal',
          'highlight': true,
          'consumable': false,
        },
        {
          'product_id': 'peleia_annual_8990',
          'label': 'Pro Anual',
          'badge': 'MELHOR VALOR',
          'subtitle': 'Anual',
          'highlight': false,
          'consumable': false,
        },
        {
          'product_id': 'peleia_sos_690',
          'label': 'Pacote SOS',
          'badge': 'ÚNICO',
          'subtitle': '3 análises',
          'highlight': false,
          'consumable': true,
        },
      ],
      'products': [
        {'id': 'p1', 'name': 'Protetor', 'brand': 'ISDIN', 'category': 'protetor', 'active': true},
      ],
    })!;

    const directProducts = [
      StoreProduct(
        'peleia_monthly_1990:monthly',
        'Mensal',
        'PeleIA Pro Mensal',
        19.90,
        'R\$ 19,90',
        'BRL',
        subscriptionPeriod: 'P1M',
      ),
      StoreProduct(
        'peleia_annual_8990:annual',
        'Anual',
        'PeleIA Pro Anual',
        89.90,
        'R\$ 89,90',
        'BRL',
        subscriptionPeriod: 'P1Y',
      ),
      StoreProduct(
        'peleia_sos_690',
        'SOS',
        'Pacote SOS',
        6.90,
        'R\$ 6,90',
        'BRL',
      ),
    ];

    final plans = SubscriptionPlan.fromStore(
      config: config,
      packages: const [],
      directProducts: directProducts,
      allowWithoutStore: false,
    );

    expect(plans.length, equals(3));
    expect(plans[0].productId, equals('peleia_monthly_1990'));
    expect(plans[0].priceLabel, equals('R\$ 19,90'));
    expect(plans[0].periodLabel, equals('/ mês'));

    expect(plans[1].productId, equals('peleia_annual_8990'));
    expect(plans[1].priceLabel, equals('R\$ 89,90'));
    expect(plans[1].periodLabel, equals('/ ano'));

    expect(plans[2].productId, equals('peleia_sos_690'));
    expect(plans[2].priceLabel, equals('R\$ 6,90'));
    expect(plans[2].periodLabel, equals('único'));
    expect(plans[2].isConsumable, isTrue);
  });
}
