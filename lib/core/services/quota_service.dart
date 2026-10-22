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

import '../config/app_config.dart';

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
  static const String _freeCountKey = 'quota_free_scans_used';
  static const String _sosCreditsKey = 'quota_sos_credits';
  static const String _proScanDateKey = 'quota_pro_last_scan_date';
  static const String _proScanCountKey = 'quota_pro_scans_today_count';

  static int freeLifetime = 1;
  static int maxProDailyScans = 2;
  static int sosPackSize = 3;

  static void applyLimits(QuotaLimits limits) {
    freeLifetime = limits.freeLifetime;
    maxProDailyScans = limits.proDaily;
    sosPackSize = limits.sosCredits;
  }

  /// Espelha o que o Worker já debitou, para a interface não contar de novo.
  static Future<void> mirrorFromServer(Map<String, dynamic> quota) async {
    final prefs = await SharedPreferences.getInstance();
    final freeRemaining = _asInt(quota['free_remaining']);
    final proRemaining = _asInt(quota['pro_remaining_today']);
    final sosRemaining = _asInt(quota['sos_remaining']);
    if (freeRemaining != null) {
      await prefs.setInt(_freeCountKey, (freeLifetime - freeRemaining).clamp(0, freeLifetime));
      await prefs.setBool(_freeUsedKey, freeRemaining <= 0);
    }
    if (sosRemaining != null) await prefs.setInt(_sosCreditsKey, sosRemaining);
    if (proRemaining != null && quota['is_pro'] == true) {
      await prefs.setString(_proScanDateKey, _getTodayString());
      await prefs.setInt(_proScanCountKey, (maxProDailyScans - proRemaining).clamp(0, maxProDailyScans));
    }
  }

  /// Verifica se o usuário atual tem cota para fazer nova análise
  static Future<QuotaStatus> checkQuota({required bool isPro}) async {
    final prefs = await SharedPreferences.getInstance();

    final freeUsedCount = await _freeUsedCount(prefs);
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
    final freeRemaining = freeLifetime - freeUsedCount;
    if (freeRemaining > 0) {
      return QuotaStatus(
        canScan: true,
        blockReason: QuotaBlockReason.none,
        freeRemaining: freeRemaining,
        proRemainingToday: 0,
        sosCredits: sosCredits,
        statusText: freeRemaining == 1
            ? '1 análise gratuita de boas-vindas.'
            : '$freeRemaining análises gratuitas.',
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

    final used = await _freeUsedCount(prefs);
    final next = used + 1;
    await prefs.setInt(_freeCountKey, next);
    await prefs.setBool(_freeUsedKey, next >= freeLifetime);
    debugPrint('🎁 Análise cortesia consumida ($next/$freeLifetime)');
  }

  static Future<int> _freeUsedCount(SharedPreferences prefs) async {
    if (prefs.containsKey(_freeCountKey)) return prefs.getInt(_freeCountKey) ?? 0;
    return (prefs.getBool(_freeUsedKey) ?? false) ? 1 : 0;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return null;
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
