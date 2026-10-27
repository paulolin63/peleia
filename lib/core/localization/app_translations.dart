// ============================================================
//  lib/core/localization/app_translations.dart
//
//  Sistema de internacionalização e suporte bilíngue (PT / EN)
//  Permite alternar instantaneamente entre Português e Inglês
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { pt, en }

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  static const _prefKey = 'app_language_code';

  AppLanguageNotifier() : super(AppLanguage.pt) {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey) ?? 'pt';
    state = code == 'en' ? AppLanguage.en : AppLanguage.pt;
  }

  Future<void> toggleLanguage() async {
    final next = state == AppLanguage.pt ? AppLanguage.en : AppLanguage.pt;
    await setLanguage(next);
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, lang == AppLanguage.en ? 'en' : 'pt');
  }
}

final appLanguageProvider =
    StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier();
});

class Tr {
  final AppLanguage lang;
  const Tr(this.lang);

  bool get isEn => lang == AppLanguage.en;

  // ── Botões Globais & Status ─────────────────────────────────
  String get langCode => isEn ? 'en' : 'pt';
  String get langLabel => isEn ? '🇺🇸 EN' : '🇧🇷 PT';
  String get switchLangTooltip => isEn ? 'Mudar para Português' : 'Switch to English';
  String get continueBtn => isEn ? 'Continue' : 'Continuar';
  String get backBtn => isEn ? 'Back' : 'Voltar';
  String get closeBtn => isEn ? 'Close' : 'Fechar';
  String get understood => isEn ? 'Understood' : 'Entendido';
  String get retry => isEn ? 'Try again' : 'Tentar novamente';
  String get loading => isEn ? 'Loading...' : 'Carregando...';
  String get error => isEn ? 'Error' : 'Erro';
  String get viewDetails => isEn ? 'View Details' : 'Ver detalhes';
  String get share => isEn ? 'Share' : 'Compartilhar';
  String get downloadPdf => isEn ? 'Download PDF' : 'Baixar PDF';
  String get buyNow => isEn ? 'Buy' : 'Comprar';
  String get whereToBuy => isEn ? 'Where to buy' : 'Onde comprar';

  // ── Navegação / Abas ────────────────────────────────────────
  String get navHome => isEn ? 'Home' : 'Início';
  String get navScan => isEn ? 'Scan' : 'Analisar';
  String get navHistory => isEn ? 'History' : 'Histórico';
  String get navProfile => isEn ? 'Profile' : 'Perfil';
  String get navPro => isEn ? 'Pro' : 'Pro';

  // ── Dashboard ───────────────────────────────────────────────
  String get dashGreeting => isEn ? 'Hello! Ready for today\'s skincare?' : 'Olá! Pronta para cuidar da pele hoje?';
  String get dashTodayRoutine => isEn ? 'Today\'s Routine' : 'Rotina de Hoje';
  String get dashMorning => isEn ? 'Morning' : 'Manhã';
  String get dashNight => isEn ? 'Night' : 'Noite';
  String get dashSunTitle => isEn ? 'Daily Sun Protection' : 'Proteção Solar Diária';
  String get dashSunDesc => isEn
      ? 'UV radiation in Brazil is intense year-round. Use SPF 50+ every morning and reapply every 2 hours outdoors.'
      : 'O índice UV no Brasil é intenso o ano todo. Aplique protetor FPS 50+ pela manhã e reaplique a cada 2h se estiver ao sol.';
  String get dashLastScore => isEn ? 'Latest Skin Score' : 'Última Pontuação';
  String get dashHistoryPrompt => isEn ? 'Track your evolution' : 'Acompanhe sua evolução';
  String get dashQuickScan => isEn ? 'Scan Skin with AI' : 'Analisar com IA';
  String get dashQuotaBadge => isEn ? 'Free Test Scans Remaining' : 'Análises de Teste Restantes';

  // ── Tela de Escaneamento (Scan Screen) ───────────────────────
  String get scanTitle => isEn ? 'AI Skin Analysis' : 'Análise Facial IA';
  String get scanSubtitle => isEn
      ? 'Position your face inside the oval frame in natural light'
      : 'Posicione seu rosto dentro da moldura oval com luz natural';
  String get scanMainBtn => isEn ? '📸 Analyze My Skin' : '📸 Analisar Minha Pele';
  String get scanGalleryBtn => isEn ? '🖼️ Choose from Gallery' : '🖼️ Escolher da Galeria';
  String get scanAccuracyTitle => isEn ? 'For 100% accurate AI diagnosis:' : 'Para a IA acertar com 100% de precisão:';
  String get scanTipLight => isEn ? 'Natural Light' : 'Luz Natural';
  String get scanTipFilter => isEn ? 'No Beauty Filters' : 'Sem Filtro';
  String get scanTipMake => isEn ? 'Clean Skin' : 'Pele Limpa';

  // Animação de Análise
  String get stepSkinType => isEn ? '🔬 Detecting skin type...' : '🔬 Detectando tipo de pele...';
  String get stepOiliness => isEn ? '💧 Analyzing oiliness & pores...' : '💧 Analisando oleosidade e poros...';
  String get stepAcne => isEn ? '😤 Mapping acne & blemishes...' : '😤 Mapeando acne e cravos...';
  String get stepUv => isEn ? '☀️ Calculating UV protection risk...' : '☀️ Calculando risco UV...';
  String get stepRoutine => isEn ? '📋 Generating custom skincare prescription...' : '📋 Criando sua rotina personalizada...';

  // ── Tela de Resultado (Result Screen) ────────────────────────
  String get resultTitle => isEn ? 'Skin Diagnosis & Routine' : 'Diagnóstico da Pele & Rotina';
  String get resultOverallScore => isEn ? 'Overall Skin Score' : 'Pontuação Geral';
  String get resultIndicators => isEn ? 'Clinical Indicators' : 'Indicadores Clínicos';
  String get indicatorSkinType => isEn ? 'Skin Type' : 'Tipo de Pele';
  String get indicatorOiliness => isEn ? 'Oiliness' : 'Oleosidade';
  String get indicatorAcne => isEn ? 'Acne & Blemishes' : 'Acne e Cravos';
  String get indicatorSpots => isEn ? 'UV / Dark Spots' : 'Manchas UV';
  String get indicatorHydration => isEn ? 'Hydration' : 'Hidratação';
  String get indicatorSensitivity => isEn ? 'Sensitivity' : 'Sensibilidade';
  String get indicatorPores => isEn ? 'Pores' : 'Poros';

  String get routineTitle => isEn ? 'Daily Intelligent Routine' : 'Rotina Diária Inteligente';
  String get routineMorningTitle => isEn ? '☀️ Morning Routine' : '☀️ Rotina Matinal';
  String get routineNightTitle => isEn ? '🌙 Night Routine' : '🌙 Rotina Noturna';
  String get recommendedProductsTitle => isEn ? 'Recommended Products for You' : 'Produtos Recomendados para Você';
  String get productsDesc => isEn
      ? 'Selected specifically for your skin metrics, excluding avoided ingredients.'
      : 'Selecionados sob medida para os seus indicadores, sem ingredientes a evitar.';
  String get officialStores => isEn ? 'Official Partner Stores' : 'Lojas Parceiras';

  // ── Histórico (History Screen) ──────────────────────────────
  String get historyTitle => isEn ? 'Skin Evolution' : 'Evolução da Pele';
  String get historySubtitle => isEn ? 'Before & after timeline of your analyses' : 'Antes & depois e linha do tempo de análises';
  String get historyEmpty => isEn ? 'No skin scans yet. Take your first selfie!' : 'Nenhuma análise ainda. Faça sua primeira selfie!';
  String get historyDetailTitle => isEn ? 'Analysis Details' : 'Detalhes da Análise';
  String get historyProductsInReport => isEn ? 'Products suggested in this scan:' : 'Produtos indicados nesta análise:';
  String get historyFullReportTitle => isEn ? 'AI Prescription & Routine:' : 'Prescrição e Rotina da IA:';

  // ── Tradução de Tipos de Pele ────────────────────────────────
  String translateSkinType(String raw) {
    if (!isEn) return raw.toUpperCase();
    final lower = raw.toLowerCase().trim();
    switch (lower) {
      case 'oleosa':
        return 'OILY';
      case 'seca':
        return 'DRY';
      case 'mista':
        return 'COMBINATION';
      case 'normal':
        return 'NORMAL';
      case 'sensivel':
      case 'sensível':
        return 'SENSITIVE';
      default:
        return raw.toUpperCase();
    }
  }

  // ── Paywall ──────────────────────────────────────────────────
  String get paywallTitle => isEn ? 'Your skin deserves\nthe best care' : 'Sua pele merece\no melhor cuidado';
  String get paywallSubtitle => isEn
      ? 'AI monitoring, personalized product matching & daily routine tracking.'
      : 'Acompanhamento com IA, rotina personalizada e produtos sob medida.';
  String get planMonthly => isEn ? 'Monthly' : 'Mensal';
  String get planAnnual => isEn ? 'Annual' : 'Anual';
  String get planSos => isEn ? 'SOS 3-Pack' : 'Pacote SOS';
  String get subscribeCTA => isEn ? 'Subscribe Now' : 'Assinar Agora';
  String get cancelAnytime => isEn ? 'Cancel anytime on Google Play' : 'Cancele quando quiser pelo Google Play';

  // ── PDF & Compartilhamento Social ───────────────────────────
  String get pdfHeaderTitle => isEn ? 'PeleIA Skin Report' : 'Relatório PeleIA';
  String get pdfHeaderSubtitle => isEn
      ? 'Intelligent AI Skin Analysis & Routine Prescription'
      : 'Relatório de Análise da Pele & Rotina Inteligente';
  String get shareHeading => isEn
      ? '✨ Just analyzed my skin with AI on PeleIA!'
      : '✨ Fiz minha análise de pele com IA no PeleIA!';
  String get shareRecommended => isEn
      ? '🌿 Recommended products for my profile:'
      : '🌿 Produtos recomendados para meu perfil:';
  String get shareCallToAction => isEn
      ? 'Discover your ideal personalized skincare routine on PeleIA!'
      : 'Descubra a rotina de skincare ideal para o seu rosto no PeleIA!';
}

final trProvider = Provider<Tr>((ref) {
  final lang = ref.watch(appLanguageProvider);
  return Tr(lang);
});
