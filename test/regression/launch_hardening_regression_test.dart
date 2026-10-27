// ============================================================
//  test/regression/launch_hardening_regression_test.dart
//
//  Suite de Regressão para Homologação de Lançamento (Launch Hardening)
//  Cobre:
//  1. Primeira análise (Marco Zero)
//  2. Comparação histórica e limiar de incerteza (Inconclusivo)
//  3. Resiliência a JSON corrompido ou incompleto da IA
//  4. Purge total de dados locais (LGPD)
//  5. Gestão de cotas diárias e limites de abuso
// ============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peleia/core/profile/user_profile.dart';
import 'package:peleia/core/services/comparison_service.dart';
import 'package:peleia/core/services/history_service.dart';
import 'package:peleia/core/services/quota_service.dart';
import 'package:peleia/features/history/data/history_entry.dart';
import 'package:peleia/features/scan/data/skin_analysis_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Launch Hardening - Suite de Testes de Regressão', () {
    // ── 1. Resiliência a JSON ──────────────────────────────
    test('1. Resiliência: Parsing de JSON incompleto ou com campos nulos', () {
      final incompleteJson = {
        'skin_type': 'oleosa',
        // scores faltando propositalmente
        'scores': {
          'oleosidade': 8,
          // outros scores ausentes
        },
        'score_geral': 68,
      };

      // Não deve lançar exceção não tratada
      final parsed = SkinAnalysisRaw.fromJson(incompleteJson);
      expect(parsed.skinType, equals('oleosa'));
      expect(parsed.scoreGeral, equals(68));
      expect(parsed.scores.oleosidade, equals(8));
      expect(parsed.scores.acneCravos, equals(3)); // fallback seguro mediano

      final decimal = SkinAnalysisRaw.fromJson({
        'score_geral': 70.6,
        'scores': {'oleosidade': 7.2},
      });
      expect(decimal.scoreGeral, equals(71));
      expect(decimal.scores.oleosidade, equals(7));
      expect(parsed.scores.manchasSolares, equals(3));
      expect(parsed.confianca, equals(0.8)); // fallback default
    });

    // ── 2. Marco Zero vs Comparação ────────────────────────
    test('2. Transição: Primeira Análise -> Segunda Análise com Comparação Inconclusiva', () {
      final scan1 = SkinAnalysisRaw(
        skinType: 'mista',
        tomDePele: 'media',
        scores: const SkinScores(
          oleosidade: 6,
          acneCravos: 4,
          manchasSolares: 3,
          sensibilidade: 2,
          hidratacao: 6,
          porosDilatados: 4,
        ),
        problemasDetectados: [],
        urgenciaProtetorSolar: 'media',
        scoreGeral: 72,
        confianca: 0.9,
        observacaoClima: '',
      );

      // Marco Zero
      final result1 = ComparisonService.compare(current: scan1, previous: null);
      expect(result1.hasPrevious, isFalse);
      expect(result1.overallScore.trend, equals(TrendDirection.inconclusive));

      // Simula segunda análise com pequena oscilação (72 -> 74: +2 pts)
      final scan2 = SkinAnalysisRaw(
        skinType: 'mista',
        tomDePele: 'media',
        scores: const SkinScores(
          oleosidade: 5, // -1 pt
          acneCravos: 4, // 0 pt
          manchasSolares: 3,
          sensibilidade: 2,
          hidratacao: 6,
          porosDilatados: 4,
        ),
        problemasDetectados: [],
        urgenciaProtetorSolar: 'media',
        scoreGeral: 74,
        confianca: 0.9,
        observacaoClima: '',
      );

      final prevEntry = HistoryEntry(
        id: 'scan_1',
        date: DateTime.now().subtract(const Duration(days: 4)),
        skinType: scan1.skinType,
        scoreGeral: scan1.scoreGeral,
        oleosidade: scan1.scores.oleosidade,
        acne: scan1.scores.acneCravos,
        manchas: scan1.scores.manchasSolares,
        hidratacao: scan1.scores.hidratacao,
        reportSnippet: '',
      );

      final result2 = ComparisonService.compare(current: scan2, previous: prevEntry);
      expect(result2.hasPrevious, isTrue);
      expect(result2.overallScore.delta, equals(2));
      // Deve classificar como inconclusivo para não induzir falso progresso
      expect(result2.overallScore.trend, equals(TrendDirection.inconclusive));
      expect(result2.isWithinNormalVariance, isTrue);
    });

    // ── 3. Ciclo de Vida do Histórico e Exclusão LGPD ──────
    test('3. LGPD: Gravação de Histórico e Purge Completo', () async {
      final scan = SkinAnalysisRaw(
        skinType: 'seca',
        tomDePele: 'clara',
        scores: const SkinScores(
          oleosidade: 2,
          acneCravos: 1,
          manchasSolares: 2,
          sensibilidade: 5,
          hidratacao: 4,
          porosDilatados: 2,
        ),
        problemasDetectados: ['ressecamento'],
        urgenciaProtetorSolar: 'baixa',
        scoreGeral: 65,
        confianca: 0.88,
        observacaoClima: '',
      );

      // Grava no histórico
      await HistoryService.saveAnalysis(
        analysis: scan,
        report: 'Relatório teste',
      );

      var entries = await HistoryService.getEntries();
      expect(entries.length, equals(1));
      expect(entries.first.skinType, equals('seca'));

      await QuotaService.consumeQuota(isPro: false);
      await UserProfileStore.save(const UserProfile(
        ageGroup: '20_35',
        note: 'alergia a fragrancia',
        avoidIngredients: ['fragrancia'],
      ));

      // Realiza exclusão total (LGPD)
      await HistoryService.clearAllHistory();

      entries = await HistoryService.getEntries();
      expect(entries, isEmpty);

      final afterPurge = await QuotaService.checkQuota(isPro: false);
      expect(afterPurge.canScan, isTrue);
      expect(afterPurge.freeRemaining, equals(QuotaService.freeLifetime));
      final profile = await UserProfileStore.load();
      expect(profile.note, isEmpty);
      expect(profile.avoidIngredients, isEmpty);
    });

    // ── 4. Proteção de Custos e Limite de Cotas ────────────
    test('4. Controle de Abuso: Limites de cota Free vs Pro', () async {
      // Usuário gratuito: análises de teste liberadas
      var status = await QuotaService.checkQuota(isPro: false);
      expect(status.canScan, isTrue);
      expect(status.freeRemaining, equals(QuotaService.freeLifetime));

      // Consome todas as análises de teste
      for (var i = 0; i < QuotaService.freeLifetime; i++) {
        await QuotaService.consumeQuota(isPro: false);
      }

      // Nova verificação gratuita: deve bloquear
      status = await QuotaService.checkQuota(isPro: false);
      expect(status.canScan, isFalse);
      expect(status.freeRemaining, equals(0));
      expect(status.blockReason, equals(QuotaBlockReason.freeUsed));

      // Adiciona crédito de emergência (SOS pack)
      await QuotaService.addSosCredits(3);
      status = await QuotaService.checkQuota(isPro: false);
      expect(status.canScan, isTrue);
      expect(status.sosCredits, equals(3));
      expect(status.blockReason, equals(QuotaBlockReason.none));
    });
  });
}
