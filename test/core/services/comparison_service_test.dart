// ============================================================
//  test/core/services/comparison_service_test.dart
//
//  Validação rigorosa dos limites e regras do ComparisonService
// ============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:peleia/core/services/comparison_service.dart';
import 'package:peleia/features/history/data/history_entry.dart';
import 'package:peleia/features/scan/data/skin_analysis_result.dart';

void main() {
  group('ComparisonService - Validação de Limites de Comparação', () {
    final mockCurrentScores = SkinScores(
      oleosidade: 5,
      acneCravos: 3,
      manchasSolares: 2,
      sensibilidade: 3,
      hidratacao: 7,
      porosDilatados: 4,
    );

    final mockCurrent = SkinAnalysisRaw(
      skinType: 'mista',
      tomDePele: 'media',
      scores: mockCurrentScores,
      problemasDetectados: ['cravos'],
      urgenciaProtetorSolar: 'alta',
      scoreGeral: 75,
      confianca: 0.92,
      observacaoClima: 'Clima quente e úmido',
    );

    test('1. Marco Zero (Primeira análise sem histórico prévio)', () {
      final result = ComparisonService.compare(
        current: mockCurrent,
        previous: null,
      );

      expect(result.hasPrevious, isFalse);
      expect(result.daysBetween, equals(0));
      expect(result.isWithinNormalVariance, isTrue);
      expect(result.overallScore.trend, equals(TrendDirection.inconclusive));
      expect(result.overallScore.delta, equals(0));
      expect(result.deterministicSummary, contains('Primeira avaliação'));
    });

    test('2. Variação pequena dentro da margem de erro (Resultado Inconclusivo)', () {
      // Diferença de apenas +2 no score e ±1 nos itens (limiar de ruído)
      final previous = HistoryEntry(
        id: 'scan_prev_1',
        date: DateTime.now().subtract(const Duration(days: 3)),
        skinType: 'mista',
        scoreGeral: 73, // Atual é 75 (+2 pts -> inconclusivo <= 3)
        oleosidade: 6,  // Atual é 5 (-1 pt -> inconclusivo <= 1)
        acne: 4,        // Atual é 3 (-1 pt -> inconclusivo <= 1)
        manchas: 2,     // Atual é 2 (0 pt -> inconclusivo)
        hidratacao: 6,  // Atual é 7 (+1 pt -> inconclusivo)
        reportSnippet: '',
      );

      final result = ComparisonService.compare(
        current: mockCurrent,
        previous: previous,
      );

      expect(result.hasPrevious, isTrue);
      expect(result.daysBetween, equals(3));
      expect(result.overallScore.delta, equals(2));
      expect(result.overallScore.trend, equals(TrendDirection.inconclusive));
      expect(result.overallScore.explanation, contains('inconclusivo'));
      expect(result.acne.trend, equals(TrendDirection.inconclusive));
      expect(result.oleosidade.trend, equals(TrendDirection.inconclusive));
      expect(result.isWithinNormalVariance, isTrue);
    });

    test('3. Melhora real estatisticamente além da margem de ruído', () {
      // Score geral subiu 10 pts, acne caiu 4 pts, oleosidade caiu 3 pts
      final previous = HistoryEntry(
        id: 'scan_prev_2',
        date: DateTime.now().subtract(const Duration(days: 14)),
        skinType: 'oleosa',
        scoreGeral: 65, // Atual é 75 (+10 pts > 3 -> improved)
        oleosidade: 8,  // Atual é 5 (-3 pts -> improved)
        acne: 7,        // Atual é 3 (-4 pts -> improved)
        manchas: 4,     // Atual é 2 (-2 pts -> improved)
        hidratacao: 4,  // Atual é 7 (+3 pts -> improved)
        reportSnippet: '',
      );

      final result = ComparisonService.compare(
        current: mockCurrent,
        previous: previous,
      );

      expect(result.overallScore.delta, equals(10));
      expect(result.overallScore.trend, equals(TrendDirection.improved));
      expect(result.acne.trend, equals(TrendDirection.improved));
      expect(result.oleosidade.trend, equals(TrendDirection.improved));
      expect(result.manchas.trend, equals(TrendDirection.improved));
      expect(result.hidratacao.trend, equals(TrendDirection.improved));
      expect(result.isWithinNormalVariance, isFalse);
    });

    test('4. Piora real estatisticamente além da margem de ruído', () {
      // Score geral caiu 10 pts, acne aumentou 4 pts
      final previous = HistoryEntry(
        id: 'scan_prev_3',
        date: DateTime.now().subtract(const Duration(days: 7)),
        skinType: 'mista',
        scoreGeral: 85, // Atual é 75 (-10 pts -> worsened)
        oleosidade: 2,  // Atual é 5 (+3 pts -> worsened)
        acne: 1,        // Atual é 3 (+2 pts -> worsened)
        manchas: 1,     // Atual é 2 (+1 pt -> inconclusivo)
        hidratacao: 9,  // Atual é 7 (-2 pts -> worsened)
        reportSnippet: '',
      );

      final result = ComparisonService.compare(
        current: mockCurrent,
        previous: previous,
      );

      expect(result.overallScore.delta, equals(-10));
      expect(result.overallScore.trend, equals(TrendDirection.worsened));
      expect(result.acne.trend, equals(TrendDirection.worsened));
      expect(result.oleosidade.trend, equals(TrendDirection.worsened));
      expect(result.hidratacao.trend, equals(TrendDirection.worsened));
      expect(result.isWithinNormalVariance, isFalse);
    });

    test('5. Inversão direcional estrita: acne/oleosidade vs hidratação', () {
      // Acne menor é melhor (negativo = improved)
      // Hidratação maior é melhor (positivo = improved)
      final previous = HistoryEntry(
        id: 'scan_prev_4',
        date: DateTime.now().subtract(const Duration(days: 5)),
        skinType: 'mista',
        scoreGeral: 75,
        oleosidade: 8, // delta = -3 (improved)
        acne: 6,       // delta = -3 (improved)
        manchas: 5,    // delta = -3 (improved)
        hidratacao: 4, // delta = +3 (improved)
        reportSnippet: '',
      );

      final result = ComparisonService.compare(
        current: mockCurrent,
        previous: previous,
      );

      expect(result.acne.delta, equals(-3));
      expect(result.acne.trend, equals(TrendDirection.improved));

      expect(result.hidratacao.delta, equals(3));
      expect(result.hidratacao.trend, equals(TrendDirection.improved));
    });
  });
}
