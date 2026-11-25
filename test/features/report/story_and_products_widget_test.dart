import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peleia/core/services/recommendation.dart';
import 'package:peleia/features/products/presentation/product_card_widgets.dart';
import 'package:peleia/features/report/presentation/story_share_sheet.dart';
import 'package:peleia/features/scan/data/skin_analysis_result.dart';

void main() {
  final sampleProducts = [
    const AffiliateProduct(
      id: 'isdin_fusion',
      name: 'Fotoprotetor Fusion Water Magic FPS 50',
      brand: 'ISDIN',
      description: 'Base aquosa ultraleve',
      priceDisplay: 'A partir de R\$ 89',
      priceEstimated: 92.9,
      store: 'amazon',
      affiliateUrl: 'https://www.amazon.com.br/s?k=isdin&tag=lin63-20',
      emoji: '☀️',
      forSkinTypes: ['oleosa'],
      category: 'protetor',
      tier: 'dermo',
    ),
    const AffiliateProduct(
      id: 'principia_nc01',
      name: 'Sérum Niacinamida 10% + Zinco',
      brand: 'Principia',
      description: 'Controle de poros e brilho',
      priceDisplay: 'A partir de R\$ 54',
      priceEstimated: 54.0,
      store: 'shopee',
      affiliateUrl: 'https://s.shopee.com.br/1BNyKckXmf',
      emoji: '✨',
      forSkinTypes: ['oleosa'],
      category: 'serum',
      tier: 'economica',
    ),
  ];

  testWidgets('StoryShareSheet renderiza card 9:16 sem overflow e exibe marcas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryShareSheet(
            score: 84,
            skinTypeLabel: 'MISTA',
            oleosidade: 6,
            acne: 3,
            manchas: 4,
            hidratacao: 8,
            products: sampleProducts,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('84'), findsOneWidget);
    expect(find.text('Pele Equilibrada'), findsOneWidget);
    expect(find.textContaining('ISDIN · Principia'), findsOneWidget);
    expect(find.text('Postar nos Stories / WhatsApp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProductBudgetFilterBar e cards exibem passo, faixa e CTA de loja', (tester) async {
    ProductBudgetTier? chosen;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ProductBudgetFilterBar(
                  selected: ProductBudgetTier.all,
                  onChanged: (t) => chosen = t,
                ),
                const SizedBox(height: 12),
                HeroAffiliateProductCard(
                  product: sampleProducts.first,
                  why: 'Prioridade: UV alto no Brasil.',
                  onTap: () {},
                ),
                RoutineAffiliateProductCard(
                  product: sampleProducts.last,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PASSO 4 · PROTETOR'), findsOneWidget);
    expect(find.text('PASSO 2 · SÉRUM'), findsOneWidget);
    expect(find.text('Ver oferta na Amazon'), findsOneWidget);
    expect(find.text('Ver oferta'), findsOneWidget);

    await tester.tap(find.text('Econômica'));
    await tester.pump();
    expect(chosen, equals(ProductBudgetTier.economica));
    expect(tester.takeException(), isNull);
  });
}
