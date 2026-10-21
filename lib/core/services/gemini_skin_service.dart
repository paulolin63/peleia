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
You are a professional dermatology AI assistant specialized in Brazilian skin types.

Analyze this facial selfie and return a JSON object with skin assessment optimized for
Brazilian climate: high UV index, tropical heat and humidity.

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
- oleosidade 7-10 = very oily (common in Brazilian humid climate)
- urgencia_protetor_solar = "alta" for morena/negra/oleosa types
- If not a clear face photo: {"error":"Foto não reconhecida como rosto. Use uma selfie com boa iluminação."}
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
  //  Gera relatório em Português do Brasil com Memória Evolutiva
  // ─────────────────────────────────────────────────────────
  Future<String> generateReport(
    SkinAnalysisRaw analysis, {
    HistoryEntry? previousEntry,
  }) async {
    initialize();

    String memorySection = '';
    String memoryHeader = '';

    if (previousEntry != null) {
      final daysDiff = DateTime.now().difference(previousEntry.date).inDays;
      final timeAgoStr = daysDiff == 0
          ? 'hoje mais cedo'
          : daysDiff == 1
              ? 'ontem'
              : 'há $daysDiff dias (${previousEntry.formattedDate})';

      memorySection = '''
MEMÓRIA HISTÓRICA DO USUÁRIO (ANÁLISE ANTERIOR FEITA $timeAgoStr):
- Score Geral anterior: ${previousEntry.scoreGeral}/100 ➔ Atual: ${analysis.scoreGeral}/100
- Oleosidade anterior: ${previousEntry.oleosidade}/10 ➔ Atual: ${analysis.scores.oleosidade}/10
- Acne/Cravos anterior: ${previousEntry.acne}/10 ➔ Atual: ${analysis.scores.acneCravos}/10
- Manchas Solares anterior: ${previousEntry.manchas}/10 ➔ Atual: ${analysis.scores.manchasSolares}/10
- Hidratação anterior: ${previousEntry.hidratacao}/10 ➔ Atual: ${analysis.scores.hidratacao}/10
''';

      memoryHeader = '''
📈 **Evolução da Sua Pele (Memória PeleIA)**
[Faça um comparativo amigável e caloroso com a análise de $timeAgoStr.
- Se houve melhora (score subiu, menos acne ou manchas): comemore como uma amiga médica, parabenize a disciplina com a rotina e o protetor solar.
- Se piorou ou a oleosidade subiu: acolha com empatia, lembre que no calor/umidade do Brasil oscilações são normais e recomende um ajuste tático rápido.]
''';
    } else {
      memoryHeader = '''
🌱 **Início da Sua Jornada de Pele**
[Acolha com carinho especial por ser a primeira análise! Diga que seu score base (${analysis.scoreGeral}/100) foi salvo na memória do app e convide-o a manter a rotina pelos próximos 7 a 14 dias para acompanhar a transformação no próximo escaneamento.]
''';
    }

    final prompt = '''
Você é uma dermatologista virtual brasileira especialista em skincare para o clima tropical do Brasil.
Seu estilo é acolhedor, descontraído e direto — como uma melhor amiga dermato ("dermofriend") que entende o sufoco de manter a pele sequinha no calor de 35°C.

Com base nesta análise, escreva um relatório de skincare altamente prático em Português do Brasil (PT-BR autêntico).
NÃO use termos de Portugal (como "ecrã", "pele mista a oleosa em excesso", "fato"). Use o linguajar brasileiro ("pele sequinha", "toque seco", "zona T", "reaplicar protetor", "brilho controlado").

ANÁLISE E SCORES DO USUÁRIO:
${jsonEncode(analysis.toJson())}

$memorySection

FORMATO EXATO OBRIGATÓRIO (use rigorosamente estes títulos e emojis):

$memoryHeader

🔍 **Diagnóstico da Sua Pele**
[2 frases diretas: diga o tipo de pele e contextualize com o clima brasileiro de alta umidade/calor. Se o fototipo for moreno/negro, alerte sobre a facilidade de manchas de sol/melasma]

⚠️ **Pontos de Atenção Urgentes**
• [Problema 1 explicado de forma prática]
• [Problema 2]
• [Problema 3 se houver]

🌅 **Rotina da Manhã (Toque Seco & Proteção)**
1. 🧴 Limpeza: [Gel de limpeza específico + ativo, ex: Ácido Salicílico ou Glicerina]
2. 💧 Tratamento: [Sérum leve/aquoso, ex: Niacinamida 10% ou Vitamina C]
3. ☀️ Protetor Solar: [FPS 50+ Toque Seco / Oil-Free — OBRIGATÓRIO todo santo dia, inclusive nublado ou home office!]

🌙 **Rotina da Noite (Reparação & Controle)**
1. 🧼 Limpeza: [Remoção profunda de resíduos de protetor solar e poluição]
2. ✨ Tratamento Noturno: [Ativo renovador, ex: Ácido Azelaico, Retinol 0,3% ou Niacinamida]
3. 💦 Hidratação: [Gel hidratante não comedogênico / aqua gel que não pesa no calor]

💡 **Segredo de Ouro para o Clima BR**
[1 dica de ouro super brasileira: ex: "Deixe lencinhos antioleosidade na bolsa", "Evite lavar o rosto com água quente do chuveiro para não dar efeito rebote", "Guarde seu sérum na geladeira no verão para acalmar a pele"]

Regras obrigatórias:
- Máximo 350 palavras
- Seja super empática e encorajadora
- Se oleosidade >= 7: enfatize "sem efeito rebote" e produtos "toque seco"
- Se manchas >= 5 ou tom_de_pele morena/negra: dê ênfase máxima à prevenção do melasma com protetor de amplo espectro
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
