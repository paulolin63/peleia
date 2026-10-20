// ============================================================
//  lib/features/scan/presentation/scan_provider.dart
//
//  Riverpod state management — Web + Android compatible
//  Usa XFile/bytes em vez de dart:io File
// ============================================================
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/gemini_skin_service.dart';
import '../../../core/services/quota_service.dart';
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
  final QuotaBlockReason quotaReason;
  final String? errorMessage;
  final String statusMessage;

  const ScanState({
    this.step = ScanStep.idle,
    this.imageBytes,
    this.analysis,
    this.report,
    this.products = const [],
    this.quotaReason = QuotaBlockReason.none,
    this.errorMessage,
    this.statusMessage = '',
  });

  ScanState copyWith({
    ScanStep? step,
    Uint8List? imageBytes,
    SkinAnalysisRaw? analysis,
    String? report,
    List<AffiliateProduct>? products,
    QuotaBlockReason? quotaReason,
    String? errorMessage,
    String? statusMessage,
  }) {
    return ScanState(
      step: step ?? this.step,
      imageBytes: imageBytes ?? this.imageBytes,
      analysis: analysis ?? this.analysis,
      report: report ?? this.report,
      products: products ?? this.products,
      quotaReason: quotaReason ?? this.quotaReason,
      errorMessage: errorMessage,
      statusMessage: statusMessage ?? this.statusMessage,
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

      final analysis = await _gemini.analyzeImageBytes(bytes);

      state = state.copyWith(
        analysis: analysis,
        statusMessage: '📋 Criando sua rotina personalizada...',
        step: ScanStep.generatingReport,
      );

      final report = await _gemini.generateReport(analysis);
      final products = ProductCatalog.getRecommendations(analysis);

      // Consome a cota após sucesso comprovado
      await QuotaService.consumeQuota(isPro: isPro);

      state = state.copyWith(
        step: ScanStep.done,
        report: report,
        products: products,
        statusMessage: '✅ Pronto!',
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
    Uint8List? imageBytes,
  }) {
    state = state.copyWith(
      step: ScanStep.done,
      analysis: analysis,
      report: report,
      products: products,
      imageBytes: imageBytes,
      statusMessage: '✅ Pronto!',
    );
  }
}

// ── Provider global ──────────────────────────────────────
final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(),
);
