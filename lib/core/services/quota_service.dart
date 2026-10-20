// ============================================================
//  lib/core/services/quota_service.dart
//
//  Controle de cotas e limites de uso:
//  - Grátis: 1 análise cortesia de boas-vindas
//  - Assinante Pro (R$ 19,90): Máximo 2 análises por dia (protege API)
//  - Pacote SOS (R$ 6,90): 3 créditos avulsos, sem validade
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum QuotaBlockReason {
  none,                // Pode analisar normalmente
  freeUsed,            // Usou a análise gratuita → mostrar Paywall
  proDailyExceeded,    // Assinante Pro já fez 2 análises hoje
  sosEmpty,            // Créditos do Pacote SOS acabaram
}

class QuotaStatus {
  final bool canScan;
  final QuotaBlockReason blockReason;
  final int freeRemaining;
  final int proRemainingToday;
  final int sosCredits;
  final String statusText;

  const QuotaStatus({
    required this.canScan,
    required this.blockReason,
    required this.freeRemaining,
    required this.proRemainingToday,
    required this.sosCredits,
    required this.statusText,
  });
}

class QuotaService {
  static const String _freeUsedKey = 'quota_free_analysis_used';
  static const String _sosCreditsKey = 'quota_sos_credits';
  static const String _proScanDateKey = 'quota_pro_last_scan_date';
  static const String _proScanCountKey = 'quota_pro_scans_today_count';

  static const int maxProDailyScans = 2; // Limite diário do Pro (manhã e noite)

  /// Verifica se o usuário atual tem cota para fazer nova análise
  static Future<QuotaStatus> checkQuota({required bool isPro}) async {
    final prefs = await SharedPreferences.getInstance();

    final freeUsed = prefs.getBool(_freeUsedKey) ?? false;
    final sosCredits = prefs.getInt(_sosCreditsKey) ?? 0;

    // ── 1. Assinante Pro: limite de 2 análises por dia ─────────
    if (isPro) {
      final todayStr = _getTodayString();
      final lastDate = prefs.getString(_proScanDateKey) ?? '';
      int todayCount = 0;

      if (lastDate == todayStr) {
        todayCount = prefs.getInt(_proScanCountKey) ?? 0;
      }

      final remaining = maxProDailyScans - todayCount;

      if (todayCount >= maxProDailyScans) {
        return QuotaStatus(
          canScan: false,
          blockReason: QuotaBlockReason.proDailyExceeded,
          freeRemaining: 0,
          proRemainingToday: 0,
          sosCredits: sosCredits,
          statusText: 'Você atingiu o limite de $maxProDailyScans análises diárias do Pro.',
        );
      }

      return QuotaStatus(
        canScan: true,
        blockReason: QuotaBlockReason.none,
        freeRemaining: 0,
        proRemainingToday: remaining,
        sosCredits: sosCredits,
        statusText: 'Pro: $remaining de $maxProDailyScans análises disponíveis hoje.',
      );
    }

    // ── 2. Pacote SOS: se tem créditos comprados avulsos ────────
    if (sosCredits > 0) {
      return QuotaStatus(
        canScan: true,
        blockReason: QuotaBlockReason.none,
        freeRemaining: 0,
        proRemainingToday: 0,
        sosCredits: sosCredits,
        statusText: '$sosCredits crédito(s) SOS restante(s).',
      );
    }

    // ── 3. Usuário Gratuito: 1 análise de teste ─────────────────
    if (!freeUsed) {
      return const QuotaStatus(
        canScan: true,
        blockReason: QuotaBlockReason.none,
        freeRemaining: 1,
        proRemainingToday: 0,
        sosCredits: 0,
        statusText: '1 análise gratuita de boas-vindas.',
      );
    }

    // ── 4. Bloqueado: já usou a gratuita e não tem Pro nem SOS ─
    return const QuotaStatus(
      canScan: false,
      blockReason: QuotaBlockReason.freeUsed,
      freeRemaining: 0,
      proRemainingToday: 0,
      sosCredits: 0,
      statusText: 'Sua análise gratuita foi utilizada.',
    );
  }

  /// Consome 1 cota de análise após o sucesso do Gemini
  static Future<void> consumeQuota({required bool isPro}) async {
    final prefs = await SharedPreferences.getInstance();

    if (isPro) {
      final todayStr = _getTodayString();
      final lastDate = prefs.getString(_proScanDateKey) ?? '';
      int todayCount = 0;

      if (lastDate == todayStr) {
        todayCount = prefs.getInt(_proScanCountKey) ?? 0;
      }

      await prefs.setString(_proScanDateKey, todayStr);
      await prefs.setInt(_proScanCountKey, todayCount + 1);
      debugPrint('💳 Pro cota consumida: ${todayCount + 1}/$maxProDailyScans hoje');
      return;
    }

    final sosCredits = prefs.getInt(_sosCreditsKey) ?? 0;
    if (sosCredits > 0) {
      await prefs.setInt(_sosCreditsKey, sosCredits - 1);
      debugPrint('⚡ Crédito SOS consumido: ${sosCredits - 1} restante(s)');
      return;
    }

    // Consome a análise gratuita inicial
    await prefs.setBool(_freeUsedKey, true);
    debugPrint('🎁 Análise cortesia consumida');
  }

  /// Adiciona créditos após compra de Pacote SOS
  static Future<void> addSosCredits(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_sosCreditsKey) ?? 0;
    await prefs.setInt(_sosCreditsKey, current + count);
    debugPrint('💰 +$count créditos SOS adicionados (Total: ${current + count})');
  }

  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
