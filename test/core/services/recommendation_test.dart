import 'package:flutter_test/flutter_test.dart';
import 'package:peleia/core/config/app_config.dart';
import 'package:peleia/core/profile/user_profile.dart';
import 'package:peleia/core/services/recommendation.dart';
import 'package:peleia/features/scan/data/skin_analysis_result.dart';

void main() {
  AppConfig config() {
    final parsed = AppConfig.tryParse({
      'schema_version': 1,
      'config_version': 'test',
      'quota': {'free_lifetime': 1, 'pro_daily': 2, 'sos_credits': 3},
      'recommendation': {'max_products': 4, 'required_categories': ['protetor']},
      'profile_options': {
        'ingredients': [
          {'id': 'acido_salicilico', 'label': 'Ácido salicílico', 'keywords': ['salicilico']},
          {'id': 'retinoides', 'label': 'Retinol', 'keywords': ['retinol']},
        ],
        'conditions': [
          {'id': 'gestante', 'label': 'Gestante ou amamentando', 'excludes': ['retinoides', 'acido_salicilico']},
        ],
      },
      'products': [
        {
          'id': 'sali',
          'name': 'Gel salicílico',
          'brand': 'Principia',
          'category': 'limpeza',
          'store': 'shopee',
          'ingredients': ['acido_salicilico'],
          'priority': 10,
          'active': true,
          'for_skin_types': ['oleosa'],
        },
        {
          'id': 'retinol',
          'name': 'Sérum retinol',
          'brand': 'Sallve',
          'category': 'serum',
          'store': 'amazon',
          'ingredients': ['retinoides'],
          'priority': 20,
          'active': true,
          'for_skin_types': ['oleosa'],
        },
        {
          'id': 'sun',
          'name': 'Protetor FPS 60',
          'brand': 'Episol',
          'category': 'protetor',
          'store': 'mercadolivre',
          'ingredients': [],
          'priority': 5,
          'active': true,
          'for_skin_types': ['seca'],
        },
        {
          'id': 'sun_bad',
          'name': 'Protetor com retinol',
          'brand': 'MarcaX',
          'category': 'protetor',
          'store': 'amazon',
          'ingredients': ['retinoides'],
          'priority': 50,
          'active': true,
          'for_skin_types': ['oleosa'],
        },
        {
          'id': 'ml_clean',
          'name': 'Limpeza ML',
          'brand': 'Needs',
          'category': 'limpeza',
          'store': 'mercadolivre',
          'ingredients': [],
          'priority': 8,
          'active': true,
          'for_skin_types': ['oleosa'],
        },
        {
          'id': 'amz_clean',
          'name': 'Limpeza Amazon',
          'brand': 'CeraVe',
          'category': 'limpeza',
          'store': 'amazon',
          'ingredients': [],
          'priority': 9,
          'active': true,
          'for_skin_types': ['oleosa'],
        },
        {
          'id': 'shp_extra',
          'name': 'Extra Shopee',
          'brand': 'Actine',
          'category': 'serum',
          'store': 'shopee',
          'ingredients': [],
          'priority': 30,
          'active': true,
          'for_skin_types': ['oleosa'],
        },
      ],
    });
    expect(parsed, isNotNull);
    return parsed!;
  }

  const analysis = SkinAnalysisRaw(
    skinType: 'oleosa',
    tomDePele: 'media',
    scores: SkinScores(
      oleosidade: 8,
      acneCravos: 4,
      manchasSolares: 2,
      sensibilidade: 2,
      hidratacao: 5,
      porosDilatados: 4,
    ),
    problemasDetectados: const [],
    urgenciaProtetorSolar: 'alta',
    scoreGeral: 60,
    confianca: 0.9,
    observacaoClima: '',
  );

  test('config de esquema desconhecido é ignorada', () {
    expect(AppConfig.tryParse({'schema_version': 99, 'products': []}), isNull);
  });

  test('ingrediente evitado some e gestante não recebe retinoide', () {
    final result = recommendProducts(
      config: config(),
      analysis: analysis,
      profile: const UserProfile(conditions: ['gestante']),
    );
    final ids = result.products.map((p) => p.id).toList();
    expect(ids, isNot(contains('sali')));
    expect(ids, isNot(contains('retinol')));
    expect(ids, isNot(contains('sun_bad')));
    expect(ids, contains('sun'));
    expect(result.missingSunscreen, isFalse);
  });

  test('não força protetor quando todos foram excluídos', () {
    final result = recommendProducts(
      config: config(),
      analysis: analysis,
      profile: const UserProfile(avoidIngredients: ['retinoides'], note: 'alergia a Episol'),
    );
    expect(result.products.map((p) => p.id), isNot(contains('sun')));
    expect(result.products.map((p) => p.id), isNot(contains('sun_bad')));
    expect(result.missingSunscreen, isTrue);
  });

  test('lista cobre Shopee, Mercado Livre e Amazon', () {
    final result = recommendProducts(
      config: config(),
      analysis: analysis,
      profile: const UserProfile(),
    );
    final stores = result.products.map((p) => p.store).toSet();
    expect(stores, containsAll(['shopee', 'mercadolivre', 'amazon']));
  });

  test('equilibra os 4 passos da rotina sem repetir categoria à toa', () {
    final parsed = AppConfig.tryParse({
      'schema_version': 1,
      'config_version': 'test_4steps',
      'quota': {'free_lifetime': 1, 'pro_daily': 2, 'sos_credits': 3},
      'recommendation': {'max_products': 4, 'required_categories': ['protetor']},
      'profile_options': {'ingredients': [], 'conditions': []},
      'products': [
        {
          'id': 'clean_1', 'name': 'Gel 1', 'brand': 'CeraVe', 'category': 'limpeza',
          'store': 'amazon', 'ingredients': [], 'priority': 99, 'active': true,
          'price_estimated': 64.9, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'clean_2', 'name': 'Gel 2', 'brand': 'Principia', 'category': 'limpeza',
          'store': 'mercadolivre', 'ingredients': [], 'priority': 98, 'active': true,
          'price_estimated': 44.0, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'clean_3', 'name': 'Gel 3', 'brand': 'Darrow', 'category': 'limpeza',
          'store': 'shopee', 'ingredients': [], 'priority': 97, 'active': true,
          'price_estimated': 47.9, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'serum_1', 'name': 'Sérum Niacinamida', 'brand': 'Principia', 'category': 'serum',
          'store': 'shopee', 'ingredients': [], 'priority': 70, 'active': true,
          'price_estimated': 54.0, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'hidra_1', 'name': 'Hydro Boost', 'brand': 'Neutrogena', 'category': 'hidratante',
          'store': 'amazon', 'ingredients': [], 'priority': 60, 'active': true,
          'price_estimated': 72.9, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'sun_1', 'name': 'Protetor FPS 60', 'brand': 'Sallve', 'category': 'protetor',
          'store': 'mercadolivre', 'ingredients': [], 'priority': 50, 'active': true,
          'price_estimated': 64.9, 'for_skin_types': ['oleosa'],
        },
      ],
    })!;

    final result = recommendProducts(
      config: parsed,
      analysis: analysis,
      profile: const UserProfile(),
    );

    final categories = result.products.map((p) => p.category).toSet();
    expect(result.products.length, equals(4));
    expect(categories, containsAll(['limpeza', 'serum', 'hidratante', 'protetor']));
  });

  test('filtro de orçamento econômica vs dermocosméticos respeita faixa e evita ingredientes', () {
    final parsed = AppConfig.tryParse({
      'schema_version': 1,
      'config_version': 'test_tiers',
      'quota': {'free_lifetime': 1, 'pro_daily': 2, 'sos_credits': 3},
      'recommendation': {'max_products': 4, 'required_categories': ['protetor']},
      'profile_options': {
        'ingredients': [
          {'id': 'acido_salicilico', 'label': 'Ácido salicílico', 'keywords': ['salicilico']},
        ],
        'conditions': [],
      },
      'products': [
        {
          'id': 'eco_clean', 'name': 'Gel Principia', 'brand': 'Principia', 'category': 'limpeza',
          'store': 'mercadolivre', 'tier': 'economica', 'ingredients': [], 'priority': 70, 'active': true,
          'price_estimated': 44.0, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'dermo_clean', 'name': 'Effaclar Gel', 'brand': 'La Roche-Posay', 'category': 'limpeza',
          'store': 'amazon', 'tier': 'dermo', 'ingredients': [], 'priority': 85, 'active': true,
          'price_estimated': 69.9, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'eco_serum', 'name': 'Niacinamida Principia', 'brand': 'Principia', 'category': 'serum',
          'store': 'shopee', 'tier': 'economica', 'ingredients': [], 'priority': 75, 'active': true,
          'price_estimated': 54.0, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'dermo_serum', 'name': 'Mineral 89', 'brand': 'Vichy', 'category': 'serum',
          'store': 'amazon', 'tier': 'dermo', 'ingredients': [], 'priority': 88, 'active': true,
          'price_estimated': 109.9, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'eco_sun', 'name': 'Protetor Sallve', 'brand': 'Sallve', 'category': 'protetor',
          'store': 'mercadolivre', 'tier': 'economica', 'ingredients': [], 'priority': 65, 'active': true,
          'price_estimated': 64.9, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'dermo_sun', 'name': 'Fusion Water', 'brand': 'ISDIN', 'category': 'protetor',
          'store': 'amazon', 'tier': 'dermo', 'ingredients': [], 'priority': 95, 'active': true,
          'price_estimated': 92.9, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'eco_hidra', 'name': 'Hydro Boost', 'brand': 'Neutrogena', 'category': 'hidratante',
          'store': 'amazon', 'tier': 'economica', 'ingredients': [], 'priority': 80, 'active': true,
          'price_estimated': 72.9, 'for_skin_types': ['oleosa'],
        },
        {
          'id': 'dermo_hidra', 'name': 'Cicaplast B5+', 'brand': 'La Roche-Posay', 'category': 'hidratante',
          'store': 'amazon', 'tier': 'dermo', 'ingredients': [], 'priority': 82, 'active': true,
          'price_estimated': 94.9, 'for_skin_types': ['oleosa'],
        },
      ],
    })!;

    final eco = recommendProducts(
      config: parsed,
      analysis: analysis,
      profile: const UserProfile(),
      budgetTier: ProductBudgetTier.economica,
    );
    expect(eco.products.length, equals(4));
    expect(eco.products.every((p) => p.isEconomica), isTrue);
    expect(eco.products.map((p) => p.category).toSet(),
        containsAll(['limpeza', 'serum', 'hidratante', 'protetor']));

    final dermo = recommendProducts(
      config: parsed,
      analysis: analysis,
      profile: const UserProfile(),
      budgetTier: ProductBudgetTier.dermo,
    );
    expect(dermo.products.length, equals(4));
    expect(dermo.products.every((p) => p.isDermo), isTrue);
    expect(dermo.products.map((p) => p.category).toSet(),
        containsAll(['limpeza', 'serum', 'hidratante', 'protetor']));
  });
}
