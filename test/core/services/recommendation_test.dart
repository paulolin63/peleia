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
          'ingredients': ['retinoides'],
          'priority': 50,
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
}
