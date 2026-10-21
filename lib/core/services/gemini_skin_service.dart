// ============================================================
//  lib/core/services/gemini_skin_service.dart
//
//  🔬 CORE ENGINE — Gemini Vision API
//  Web-compatible: usa Uint8List em vez de dart:io File
// ============================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;

import '../../features/history/data/history_entry.dart';
import '../../features/scan/data/skin_analysis_result.dart';
import 'comparison_service.dart';

// Importação condicional de dart:io — só disponível em mobile/desktop
// No Web usamos XFile.readAsBytes() antes de chamar o serviço.
export 'gemini_skin_service.dart';

class GeminiSkinService {
  GeminiSkinService._();
  static final GeminiSkinService instance = GeminiSkinService._();

  late final GenerativeModel _visionModel;
  late final GenerativeModel _reportModel;
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;

    // 1️⃣ Tenta dotenv (.env file — funciona em Android/iOS/desktop)
    String apiKey = '';
    try {
      apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    } catch (_) {}

    // 2️⃣ Fallback: --dart-define (funciona no Web e CI/CD)
    if (apiKey.isEmpty) {
      apiKey = const String.fromEnvironment('GEMINI_API_KEY');
    }

    if (apiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY não encontrada!\n'
        '• Web: flutter run -d chrome --dart-define=GEMINI_API_KEY=AIza...\n'
        '• Android: adicione ao arquivo .env',
      );
    }

    _visionModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 1024,
        responseMimeType: 'application/json',
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
      ],
    );

    _reportModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 2048,
      ),
    );

    _initialized = true;
  }

  // ─────────────────────────────────────────────────────────
  //  Analisa imagem a partir de bytes (Web + Android + iOS)
  //  Chame sempre com bytes — o chamador lê o arquivo/XFile
  // ─────────────────────────────────────────────────────────
  Future<SkinAnalysisRaw> analyzeImageBytes(Uint8List rawBytes) async {
    initialize();

    final bytes = await _compressBytes(rawBytes);

    const prompt = '''
You are a cosmetic skincare routine assistant specialized in Brazilian visual skin observations.

Analyze this facial selfie and return a JSON object with cosmetic visual skin assessment optimized for
Brazilian climate: high UV index, tropical heat and humidity.

IMPORTANT LEGAL & MEDICAL NOTICE:
This is strictly a cosmetic visual evaluation of a selfie photo for daily skincare routines.
It is NOT a medical diagnosis, clinical assessment, or dermatological treatment.

IMPORTANT: Return ONLY valid JSON. No markdown, no explanation, no code blocks.

{
  "skin_type": "oleosa" | "seca" | "mista" | "normal" | "sensivel",
  "tom_de_pele": "muito_clara" | "clara" | "media" | "morena" | "morena_escura" | "negra",
  "scores": {
    "oleosidade": <integer 0-10>,
    "acne_cravos": <integer 0-10>,
    "manchas_solares": <integer 0-10>,
    "sensibilidade": <integer 0-10>,
    "hidratacao": <integer 0-10>,
    "poros_dilatados": <integer 0-10>
  },
  "problemas_detectados": ["acne_ativa","cravos","manchas_solares","melasma",
    "poros_dilatados","oleosidade_excessiva","vermelhidao","ressecamento","olheiras"],
  "urgencia_protetor_solar": "alta" | "media" | "baixa",
  "score_geral": <integer 0-100>,
  "confianca": <float 0.0-1.0>,
  "observacao_clima": "<string about Brazilian climate impact>"
}

Rules:
- oleosidade 7-10 = high visible oiliness / shine (common in Brazilian humid climate)
- urgencia_protetor_solar = "alta" for morena/negra/oleosa types
- If photo is blurry, uncentered, or poor lighting: {"error":"Foto com baixa nitidez ou iluminação inadequada. Tire uma selfie frontal nítida com luz natural."}
- If not a clear face photo: {"error":"Rosto não detectado com clareza. Centralize seu rosto com boa luz sem maquiagem pesada."}
''';

    try {
      final response = await _visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', bytes),
        ]),
      ]);

      final text = response.text ?? '';
      if (text.isEmpty) throw Exception('Resposta vazia da IA. Tente novamente.');

      // Remove possíveis blocos de markdown que o modelo inserir
      final cleaned = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> json = jsonDecode(cleaned);
      if (json.containsKey('error')) throw Exception(json['error'] as String);

      return SkinAnalysisRaw.fromJson(json);
    } on FormatException catch (e) {
      throw Exception('Erro ao processar JSON da IA: $e');
    }
  }

  // ─────────────────────────────────────────────────────────
  //  Gera relatório em Português do Brasil com Separação Causal e Ética
  // ─────────────────────────────────────────────────────────
  Future<String> generateReport(
    SkinAnalysisRaw analysis, {
    HistoryEntry? previousEntry,
    SkinComparisonResult? comparison,
  }) async {
    initialize();

    String memorySection = '';
    String memoryHeader = '';

    // Se temos o resultado determinístico do ComparisonService, usamos ele
    final comp = comparison ??
        (previousEntry != null
            ? ComparisonService.compare(current: analysis, previous: previousEntry)
            : null);

    if (comp != null && comp.hasPrevious) {
      memorySection = '''
FATOS MATEMÁTICOS VERIFICADOS (NÃO INVENTE NÚMEROS NEM CAUSALIDADE DIRETA):
${comp.deterministicSummary}
''';

      memoryHeader = '''
📈 **Acompanhamento da Sua Pele (Comparativo Visual)**
[Explique de forma acolhedora a tendência observada no comparativo acima:
- Se o indicador geral estiver estável (dentro da variação esperada): explique com naturalidade que a pele manteve o equilíbrio e que variações de até 3 pontos decorrem de iluminação ou ângulo da foto.
- Se houver melhora visual de oleosidade ou acne: parabenize a consistência dos cuidados cosméticos.
- Se houver aumento de brilho ou acne: NÃO afirme categoricamente a causa (ex: jamais diga "porque fez calor"). Diga apenas que fatores como clima úmido, estresse ou mudanças na rotina podem ser fatores associados.]
''';
    } else {
      memoryHeader = '''
🌱 **Início da Sua Jornada de Cuidados**
[Acolha com carinho por ser a primeira avaliação visual! Explique que o indicador inicial (${analysis.scoreGeral}/100) servirá de referência cosmética para futuras selfies sob luz similar.]
''';
    }

    final prompt = '''
Você é uma assistente de rotina de skincare (dermofriend) focada em cuidados cosméticos diários para o clima do Brasil.
Seu estilo é acolhedor, descontraído, seguro e responsável.

LIMITES REGULATÓRIOS E ÉTICOS (ANVISA / GOOGLE PLAY / APPLE HEALTH):
- Este é um guia cosmético de rotina diária, NÃO é diagnóstico médico nem tratamento de doenças.
- NUNCA use termos como "diagnóstico médico", "cura" ou se passe por médico dermatologista clínico.
- NÃO afirme causalidade absoluta (não afirme razões definitivas para oscilações sem comprovação).

ANÁLISE E INDICADORES VISUAIS DO USUÁRIO:
${jsonEncode(analysis.toJson())}

$memorySection

FORMATO EXATO OBRIGATÓRIO (use rigorosamente estes títulos e emojis):

$memoryHeader

🔍 **Mapeamento Visual da Pele**
[2 frases diretas: descreva o aspecto visual da pele e contextualize com a rotina diária no calor/umidade do Brasil]

⚠️ **Pontos de Atenção para a Rotina**
• [Ponto cosmético 1 para cuidar]
• [Ponto 2]
• [Ponto 3 se houver]

🌅 **Rotina da Manhã (Toque Seco & Proteção)**
1. 🧴 Limpeza: [Gel facial suave com ativo, ex: Ácido Salicílico ou Glicerina]
2. 💧 Hidratação / Tratamento: [Sérum leve/aquoso, ex: Niacinamida 10% ou Vitamina C]
3. ☀️ Protetor Solar: [FPS 50+ Toque Seco / Oil-Free — OBRIGATÓRIO todo santo dia, inclusive nublado ou home office!]

🌙 **Rotina da Noite (Equilíbrio & Renovação)**
1. 🧼 Limpeza: [Remoção profunda de resíduos de protetor solar e poluição]
2. ✨ Tratamento Noturno: [Ativo cosmético suave renovador, ex: Ácido Azelaico, Retinol 0,3% ou Niacinamida]
3. 💦 Hidratação: [Gel hidratante não comedogênico / aqua gel que não pesa no calor]

💡 **Segredo de Ouro para o Clima BR**
[1 dica cosmética prática para o calor/umidade]

🩺 **Lembrete de Saúde da Pele**
[Se houver acne ativa intensa, dor ou manchas persistentes, lembre que lesões inflamatórias exigem avaliação presencial com um médico dermatologista.]

Regras obrigatórias:
- Máximo 340 palavras
- Seja super empática, acolhedora e cientificamente prudente
- Se oleosidade >= 7: enfatize fórmulas "toque seco" e "sem efeito rebote"
- Finalize com: "⚠️ *Guia cosmético para rotina diária. Não substitui consulta médica dermatológica.*"
''';

    final response = await _reportModel.generateContent([Content.text(prompt)]);
    return response.text ?? 'Erro ao gerar relatório. Tente novamente.';
  }

  // ─────────────────────────────────────────────────────────
  //  Comprime para max 800px, JPEG 85% antes de enviar
  // ─────────────────────────────────────────────────────────
  Future<Uint8List> _compressBytes(Uint8List bytes) async {
    try {
      final original = img.decodeImage(bytes);
      if (original == null) return bytes;

      final resized = img.copyResize(
        original,
        width: original.width > original.height ? 800 : -1,
        height: original.width > original.height ? -1 : 800,
      );
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (_) {
      return bytes; // fallback: envia original se compressão falhar
    }
  }
}
