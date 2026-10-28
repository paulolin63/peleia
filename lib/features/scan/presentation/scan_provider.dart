// ============================================================
//  lib/features/scan/presentation/scan_provider.dart
//
//  Riverpod state management — Web + Android compatible
//  Usa XFile/bytes em vez de dart:io File
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/remote_config_service.dart';
import '../../../core/profile/user_profile.dart';
import '../../../core/services/comparison_service.dart';
import '../../../core/services/evolution_reminder_service.dart';
import '../../../core/services/gemini_skin_service.dart';
import '../../../core/services/quota_service.dart';
import '../../../core/services/history_service.dart';
import '../../../core/services/recommendation.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../history/data/history_entry.dart';
import '../data/skin_analysis_result.dart';

// ── Estado do fluxo de scan ──────────────────────────────
enum ScanStep {
  idle,             // Esperando o usuário tirar foto
  capturing,        // Câmera/galeria aberta
  analyzing,        // Enviando para Gemini Vision
  generatingReport, // Gerando texto PT-BR
  done,             // Análise completa
  quotaBlocked,     // Cota esgotada (abre Paywall ou avisa)
  error,            // Algo deu errado
}

class ScanState {
  final ScanStep step;
  final Uint8List? imageBytes; // Web-safe: bytes em vez de File
  final SkinAnalysisRaw? analysis;
  final String? report;
  final List<AffiliateProduct> products;
  final int hiddenProducts;
  final bool missingSunscreen;
  final List<String> avoidedLabels;
  final QuotaBlockReason quotaReason;
  final String? errorMessage;
  final String statusMessage;
  final HistoryEntry? previousEntry; // Memória inteligente: análise anterior
  final SkinComparisonResult? comparison; // Comparação determinística

  const ScanState({
    this.step = ScanStep.idle,
    this.imageBytes,
    this.analysis,
    this.report,
    this.products = const [],
    this.hiddenProducts = 0,
    this.missingSunscreen = false,
    this.avoidedLabels = const [],
    this.quotaReason = QuotaBlockReason.none,
    this.errorMessage,
    this.statusMessage = '',
    this.previousEntry,
    this.comparison,
  });

  ScanState copyWith({
    ScanStep? step,
    Uint8List? imageBytes,
    SkinAnalysisRaw? analysis,
    String? report,
    List<AffiliateProduct>? products,
    int? hiddenProducts,
    bool? missingSunscreen,
    List<String>? avoidedLabels,
    QuotaBlockReason? quotaReason,
    String? errorMessage,
    String? statusMessage,
    HistoryEntry? previousEntry,
    SkinComparisonResult? comparison,
    bool clearPreviousEntry = false,
  }) {
    return ScanState(
      step: step ?? this.step,
      imageBytes: imageBytes ?? this.imageBytes,
      analysis: analysis ?? this.analysis,
      report: report ?? this.report,
      products: products ?? this.products,
      hiddenProducts: hiddenProducts ?? this.hiddenProducts,
      missingSunscreen: missingSunscreen ?? this.missingSunscreen,
      avoidedLabels: avoidedLabels ?? this.avoidedLabels,
      quotaReason: quotaReason ?? this.quotaReason,
      errorMessage: errorMessage,
      statusMessage: statusMessage ?? this.statusMessage,
      previousEntry: clearPreviousEntry ? null : (previousEntry ?? this.previousEntry),
      comparison: comparison ?? this.comparison,
    );
  }

  bool get isLoading =>
      step == ScanStep.analyzing || step == ScanStep.generatingReport;
}

// ── Notifier principal ───────────────────────────────────
class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier() : super(const ScanState());

  final _picker = ImagePicker();
  final _gemini = GeminiSkinService.instance;

  Future<bool> _isUserPro() async {
    final prefs = await SharedPreferences.getInstance();
    final remote = await RevenueCatService.isPremium();
    if (remote) {
      await prefs.setBool('is_premium', true);
      return true;
    }
    if (kReleaseMode) {
      await prefs.setBool('is_premium', false);
      return false;
    }
    return prefs.getBool('is_premium') ?? false;
  }

  // ── Método unificado: verifica cota, pega foto e analisa ──
  Future<void> _analyzeXFile(XFile xFile) async {
    try {
      final isPro = await _isUserPro();
      final quota = await QuotaService.checkQuota(isPro: isPro);

      if (!quota.canScan) {
        state = state.copyWith(
          step: ScanStep.quotaBlocked,
          quotaReason: quota.blockReason,
          errorMessage: quota.statusText,
        );
        return;
      }

      // Lê bytes — funciona em Web, Android, iOS, macOS
      final bytes = await xFile.readAsBytes();
      state = state.copyWith(imageBytes: bytes);

      state = state.copyWith(
        step: ScanStep.analyzing,
        statusMessage: '🔬 Analisando sua pele com IA...',
      );

      final config = await RemoteConfigService.load();
      final profile = await UserProfileStore.load();

      final analysis = await _gemini.analyzeImageBytes(bytes, profile: profile);

      state = state.copyWith(
        analysis: analysis,
        statusMessage: '📋 Consultando histórico e gerando relatório...',
        step: ScanStep.generatingReport,
      );

      // 🧠 Recupera a última análise anterior antes de salvar a nova
      final previousEntries = await HistoryService.getEntries();
      final previousEntry =
          previousEntries.isNotEmpty ? previousEntries.first : null;

      // 📊 Separação: cálculo determinístico de deltas e margem de erro
      final comparison = ComparisonService.compare(
        current: analysis,
        previous: previousEntry,
      );

      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString('app_language_code') ?? 'pt';

      final report = await _gemini.generateReport(
        analysis,
        profile: profile,
        comparison: comparison,
        lang: langCode,
      );
      final recommendation = recommendProducts(
        config: config,
        analysis: analysis,
        profile: profile,
      );

      if (!_gemini.lastCallUsedProxy) {
        await QuotaService.consumeQuota(isPro: isPro);
      }

      // Salva no histórico de evolução da pele (com produtos recomendados e relatório)
      await HistoryService.saveAnalysis(
        analysis: analysis,
        report: report,
        products: recommendation.products,
        rawImageBytes: bytes,
      );

      // Retention hook: nudge the 2nd scan that unlocks "evolution" value.
      EvolutionReminderService.instance.scheduleAfterScan();

      state = state.copyWith(
        step: ScanStep.done,
        report: report,
        products: recommendation.products,
        hiddenProducts: recommendation.hiddenCount,
        missingSunscreen: recommendation.missingSunscreen,
        avoidedLabels: recommendation.avoidedLabels,
        previousEntry: previousEntry,
        comparison: comparison,
        statusMessage: '✅ Pronto!',
      );
    } on AnalysisException catch (e) {
      final blocked = switch (e.code) {
        'FREE_QUOTA_EXCEEDED' => QuotaBlockReason.freeUsed,
        'SOS_EMPTY' => QuotaBlockReason.sosEmpty,
        'PRO_DAILY_LIMIT_REACHED' => QuotaBlockReason.proDailyExceeded,
        _ => null,
      };
      state = state.copyWith(
        step: blocked == null ? ScanStep.error : ScanStep.quotaBlocked,
        quotaReason: blocked ?? QuotaBlockReason.none,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        step: ScanStep.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ── Câmera frontal (Android/iOS) ──────────────────────
  Future<void> captureAndAnalyze() async {
    final isPro = await _isUserPro();
    final quota = await QuotaService.checkQuota(isPro: isPro);

    if (!quota.canScan) {
      state = state.copyWith(
        step: ScanStep.quotaBlocked,
        quotaReason: quota.blockReason,
        errorMessage: quota.statusText,
      );
      return;
    }

    state = state.copyWith(
      step: ScanStep.capturing,
      statusMessage: 'Abrindo câmera...',
    );

    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 90,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (picked == null) {
      state = state.copyWith(step: ScanStep.idle);
      return;
    }

    await _analyzeXFile(picked);
  }

  // ── Galeria (Web + Android + iOS) ─────────────────────
  Future<void> pickFromGallery() async {
    final isPro = await _isUserPro();
    final quota = await QuotaService.checkQuota(isPro: isPro);

    if (!quota.canScan) {
      state = state.copyWith(
        step: ScanStep.quotaBlocked,
        quotaReason: quota.blockReason,
        errorMessage: quota.statusText,
      );
      return;
    }

    state = state.copyWith(
      step: ScanStep.capturing,
      statusMessage: 'Escolhendo foto...',
    );

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (picked == null) {
      state = state.copyWith(step: ScanStep.idle);
      return;
    }

    await _analyzeXFile(picked);
  }

  void reset() {
    state = const ScanState();
  }

  // Injeção direta (usado pela WebTestScreen)
  void setResultDirectly({
    required SkinAnalysisRaw analysis,
    required String report,
    required List<AffiliateProduct> products,
    int hiddenProducts = 0,
    bool missingSunscreen = false,
    List<String> avoidedLabels = const [],
    Uint8List? imageBytes,
    HistoryEntry? previousEntry,
    SkinComparisonResult? comparison,
  }) {
    if (imageBytes != null && imageBytes.isNotEmpty) {
      HistoryService.saveAnalysis(
        analysis: analysis,
        report: report,
        rawImageBytes: imageBytes,
      );
    }

    state = state.copyWith(
      step: ScanStep.done,
      analysis: analysis,
      report: report,
      products: products,
      hiddenProducts: hiddenProducts,
      missingSunscreen: missingSunscreen,
      avoidedLabels: avoidedLabels,
      imageBytes: imageBytes,
      previousEntry: previousEntry,
      comparison: comparison,
      statusMessage: '✅ Pronto!',
    );
  }
}

// ── Provider global ──────────────────────────────────────
final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(),
);
