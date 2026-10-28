// ============================================================
//  lib/core/services/comparison_service.dart
//
//  Serviço determinístico de comparação visual e métricas
//  Separa a matemática exata da interpretação em linguagem natural
// ============================================================
import '../../features/history/data/history_entry.dart';
import '../../features/scan/data/skin_analysis_result.dart';

enum TrendDirection {
  improved,
  inconclusive, // Variação pequena / Resultado inconclusivo (margem de incerteza)
  worsened,
}

class MetricDelta {
  final String label;
  final int previousValue;
  final int currentValue;
  final int delta;
  final TrendDirection trend;
  final String explanation;

  const MetricDelta({
    required this.label,
    required this.previousValue,
    required this.currentValue,
    required this.delta,
    required this.trend,
    required this.explanation,
  });
}

class SkinComparisonResult {
  final bool hasPrevious;
  final int daysBetween;
  final MetricDelta overallScore;
  final MetricDelta acne;
  final MetricDelta oleosidade;
  final MetricDelta manchas;
  final MetricDelta hidratacao;
  final bool isWithinNormalVariance;
  final String deterministicSummary;

  const SkinComparisonResult({
    required this.hasPrevious,
    required this.daysBetween,
    required this.overallScore,
    required this.acne,
    required this.oleosidade,
    required this.manchas,
    required this.hidratacao,
    required this.isWithinNormalVariance,
    required this.deterministicSummary,
  });
}

class ComparisonService {
  /// Tolerância para variações de iluminação e ângulo (evita falsas alegações de melhora/piora)
  static const int scoreVarianceThreshold = 3; // <= 3 pontos pode ser só luz
  static const int itemVarianceThreshold = 1;  // <= 1 ponto é variação normal

  static SkinComparisonResult compare({
    required SkinAnalysisRaw current,
    HistoryEntry? previous,
  }) {
    if (previous == null) {
      return SkinComparisonResult(
        hasPrevious: false,
        daysBetween: 0,
        overallScore: MetricDelta(
          label: 'Indicador Visual',
          previousValue: current.scoreGeral,
          currentValue: current.scoreGeral,
          delta: 0,
          trend: TrendDirection.inconclusive,
          explanation: 'Ponto de partida registrado (Marco Zero)',
        ),
        acne: MetricDelta(
          label: 'Acne/Cravos',
          previousValue: current.scores.acneCravos,
          currentValue: current.scores.acneCravos,
          delta: 0,
          trend: TrendDirection.inconclusive,
          explanation: 'Nível inicial',
        ),
        oleosidade: MetricDelta(
          label: 'Oleosidade',
          previousValue: current.scores.oleosidade,
          currentValue: current.scores.oleosidade,
          delta: 0,
          trend: TrendDirection.inconclusive,
          explanation: 'Nível inicial',
        ),
        manchas: MetricDelta(
          label: 'Manchas Visíveis',
          previousValue: current.scores.manchasSolares,
          currentValue: current.scores.manchasSolares,
          delta: 0,
          trend: TrendDirection.inconclusive,
          explanation: 'Nível inicial',
        ),
        hidratacao: MetricDelta(
          label: 'Hidratação Aparente',
          previousValue: current.scores.hidratacao,
          currentValue: current.scores.hidratacao,
          delta: 0,
          trend: TrendDirection.inconclusive,
          explanation: 'Nível inicial',
        ),
        isWithinNormalVariance: true,
        deterministicSummary:
            'Primeira avaliação visual registrada com indicador base ${current.scoreGeral}/100.',
      );
    }

    final days = DateTime.now().difference(previous.date).inDays;

    // 1. Indicador geral (maior é melhor)
    final scoreDiff = current.scoreGeral - previous.scoreGeral;
    final scoreTrend = scoreDiff.abs() <= scoreVarianceThreshold
        ? TrendDirection.inconclusive
        : (scoreDiff > 0 ? TrendDirection.improved : TrendDirection.worsened);

    // 2. Acne (menor é melhor)
    final acneDiff = current.scores.acneCravos - previous.acne;
    final acneTrend = acneDiff.abs() <= itemVarianceThreshold
        ? TrendDirection.inconclusive
        : (acneDiff < 0 ? TrendDirection.improved : TrendDirection.worsened);

    // 3. Oleosidade (menor/equilibrado é melhor)
    final oilDiff = current.scores.oleosidade - previous.oleosidade;
    final oilTrend = oilDiff.abs() <= itemVarianceThreshold
        ? TrendDirection.inconclusive
        : (oilDiff < 0 ? TrendDirection.improved : TrendDirection.worsened);

    // 4. Manchas (menor é melhor)
    final spotsDiff = current.scores.manchasSolares - previous.manchas;
    final spotsTrend = spotsDiff.abs() <= itemVarianceThreshold
        ? TrendDirection.inconclusive
        : (spotsDiff < 0 ? TrendDirection.improved : TrendDirection.worsened);

    // 5. Hidratação (maior é melhor)
    final hydraDiff = current.scores.hidratacao - previous.hidratacao;
    final hydraTrend = hydraDiff.abs() <= itemVarianceThreshold
        ? TrendDirection.inconclusive
        : (hydraDiff > 0 ? TrendDirection.improved : TrendDirection.worsened);

    final isWithinNormal = scoreTrend == TrendDirection.inconclusive &&
        acneTrend == TrendDirection.inconclusive &&
        oilTrend == TrendDirection.inconclusive;

    final summary = StringBuffer();
    summary.write('Intervalo: $days dias. ');
    summary.write('Indicador geral: ${previous.scoreGeral} -> ${current.scoreGeral} ($scoreDiff pts, ${scoreTrend.name}). ');
    summary.write('Acne: ${previous.acne} -> ${current.scores.acneCravos} (${acneTrend.name}). ');
    summary.write('Oleosidade: ${previous.oleosidade} -> ${current.scores.oleosidade} (${oilTrend.name}). ');
    summary.write('Manchas: ${previous.manchas} -> ${current.scores.manchasSolares} (${spotsTrend.name}). ');
    summary.write('Hidratação: ${previous.hidratacao} -> ${current.scores.hidratacao} (${hydraTrend.name}).');

    return SkinComparisonResult(
      hasPrevious: true,
      daysBetween: days,
      overallScore: MetricDelta(
        label: 'Indicador Visual',
        previousValue: previous.scoreGeral,
        currentValue: current.scoreGeral,
        delta: scoreDiff,
        trend: scoreTrend,
        explanation: scoreTrend == TrendDirection.inconclusive
            ? 'Variação pequena • Resultado inconclusivo (margem de incerteza da foto)'
            : (scoreTrend == TrendDirection.improved
                ? 'Tendência de melhora no aspecto visual geral'
                : 'Pequena oscilação para baixo no aspecto geral'),
      ),
      acne: MetricDelta(
        label: 'Acne/Cravos',
        previousValue: previous.acne,
        currentValue: current.scores.acneCravos,
        delta: acneDiff,
        trend: acneTrend,
        explanation: acneTrend == TrendDirection.inconclusive
            ? 'Variação pequena • Aparência de acne estável'
            : (acneTrend == TrendDirection.improved
                ? 'Menor visibilidade aparente de espinhas/cravos'
                : 'Aparência de mais espinhas ou poros obstruídos'),
      ),
      oleosidade: MetricDelta(
        label: 'Oleosidade',
        previousValue: previous.oleosidade,
        currentValue: current.scores.oleosidade,
        delta: oilDiff,
        trend: oilTrend,
        explanation: oilTrend == TrendDirection.inconclusive
            ? 'Variação pequena • Brilho na zona T inconclusivo'
            : (oilTrend == TrendDirection.improved
                ? 'Aspecto visual mais matificado/seco'
                : 'Aspecto visual com maior reflexo de brilho/oleosidade'),
      ),
      manchas: MetricDelta(
        label: 'Manchas Visíveis',
        previousValue: previous.manchas,
        currentValue: current.scores.manchasSolares,
        delta: spotsDiff,
        trend: spotsTrend,
        explanation: spotsTrend == TrendDirection.inconclusive
            ? 'Variação pequena • Tonalidade visual inconclusiva'
            : (spotsTrend == TrendDirection.improved
                ? 'Tom visualmente mais uniforme'
                : 'Manchas visíveis com maior contraste'),
      ),
      hidratacao: MetricDelta(
        label: 'Hidratação Aparente',
        previousValue: previous.hidratacao,
        currentValue: current.scores.hidratacao,
        delta: hydraDiff,
        trend: hydraTrend,
        explanation: hydraTrend == TrendDirection.inconclusive
            ? 'Variação pequena • Textura de hidratação inconclusiva'
            : (hydraTrend == TrendDirection.improved
                ? 'Pele com aspecto visual mais viçoso'
                : 'Aparência de ressecamento ou aspereza'),
      ),
      isWithinNormalVariance: isWithinNormal,
      deterministicSummary: summary.toString(),
    );
  }

  /// Structured payload for the Worker (no free-form prompt text).
  static Map<String, dynamic>? toWire(SkinComparisonResult? comparison) {
    if (comparison == null || !comparison.hasPrevious) return null;
    return {
      'days': comparison.daysBetween,
      'score_prev': comparison.overallScore.previousValue,
      'score_curr': comparison.overallScore.currentValue,
      'acne_prev': comparison.acne.previousValue,
      'acne_curr': comparison.acne.currentValue,
      'oil_prev': comparison.oleosidade.previousValue,
      'oil_curr': comparison.oleosidade.currentValue,
      'spots_prev': comparison.manchas.previousValue,
      'spots_curr': comparison.manchas.currentValue,
      'hydra_prev': comparison.hidratacao.previousValue,
      'hydra_curr': comparison.hidratacao.currentValue,
    };
  }
}
