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
import 'package:http/http.dart' as http;
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
  String _proxyUrl = '';
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;

    // 0️⃣ Verifica se há backend proxy configurado (Arquitetura Segura de Produção)
    try {
      _proxyUrl = dotenv.env['GEMINI_PROXY_URL'] ?? '';
    } catch (_) {}
    if (_proxyUrl.isEmpty) {
      _proxyUrl = const String.fromEnvironment('GEMINI_PROXY_URL');
    }

    // Se estiver usando proxy seguro, não precisa expor a GEMINI_API_KEY no cliente
    if (_proxyUrl.isNotEmpty) {
      debugPrint('🛡️ GeminiSkinService: Conectado ao Proxy Seguro ($_proxyUrl)');
      _initialized = true;
      return;
    }

    // 1️⃣ Fallback para desenvolvimento local: Tenta dotenv / --dart-define
    String apiKey = '';
    try {
      apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    } catch (_) {}

    if (apiKey.isEmpty) {
      apiKey = const String.fromEnvironment('GEMINI_API_KEY');
    }

    if (apiKey.isEmpty) {
      throw Exception(
        'Configuração de API não encontrada!\n'
        '• Produção: configure GEMINI_PROXY_URL\n'
        '• Dev local: adicione GEMINI_API_KEY no .env',
      );
    }

    // 2️⃣ Configuração do modelo (Migração para versão suportada: gemini-3.6-flash ou gemini-3.8-flash)
    String modelName = '';
    try {
      modelName = dotenv.env['GEMINI_MODEL'] ?? '';
    } catch (_) {}
    if (modelName.isEmpty) {
      modelName = const String.fromEnvironment(
        'GEMINI_MODEL',
        defaultValue: 'gemini-3.6-flash',
      );
    }

    _visionModel = GenerativeModel(
      model: modelName,
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
      model: modelName,
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
  Future<SkinAnalysisRaw> analyzeImageBytes(
    Uint8List rawBytes, {
    String? ageGroup,
    String? outdoorExposure,
  }) async {
    initialize();

    final bytes = await _compressBytes(rawBytes);
    final ageDesc = _formatAgeDescription(ageGroup);
    final outdoorDesc = _formatOutdoorDescription(outdoorExposure);

    final prompt = '''
You are a cosmetic skincare routine assistant specialized in Brazilian visual skin observations.

Analyze this facial selfie and return a JSON object with cosmetic visual skin assessment optimized for
Brazilian climate: high UV index, tropical heat and humidity.

USER PROFILE CONTEXT (DECLARED BY USER):
- Age Group: $ageDesc
- Outdoor Sports & Sun Exposure: $outdoorDesc
Use this context to inform expected oiliness and barrier needs (e.g. teenagers expect higher sebum; mature skin requires deeper barrier care; outdoor athletes require higher UV awareness).

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
- urgencia_protetor_solar = "alta" for morena/negra/oleosa types or outdoor_high exposure
- If photo is blurry, uncentered, or poor lighting: {"error":"Foto com baixa nitidez ou iluminação inadequada. Tire uma selfie frontal nítida com luz natural."}
- If not a clear face photo: {"error":"Rosto não detectado com clareza. Centralize seu rosto com boa luz sem maquiagem pesada."}
''';

    try {
      String text = '';

      if (_proxyUrl.isNotEmpty) {
        // Envio seguro via Backend Proxy (sem expor API key no client)
        final res = await http.post(
          Uri.parse(_proxyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'task': 'vision',
            'image_base64': base64Encode(bytes),
            'prompt': prompt,
          }),
        );

        if (res.statusCode != 200) {
          throw Exception('Servidor de IA indisponível (${res.statusCode}). Tente novamente.');
        }

        final bodyJson = jsonDecode(res.body);
        text = bodyJson['output'] as String? ?? '';
      } else {
        // Fallback local SDK
        final response = await _visionModel.generateContent([
          Content.multi([
            TextPart(prompt),
            DataPart('image/jpeg', bytes),
          ]),
        ]);
        text = response.text ?? '';
      }

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
    String? ageGroup,
    String? outdoorExposure,
  }) async {
    initialize();

    String memorySection = '';
    String memoryHeader = '';

    final ageDesc = _formatAgeDescription(ageGroup);
    final outdoorDesc = _formatOutdoorDescription(outdoorExposure);

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

PERFIL CONTEXTUAL DO USUÁRIO (DECLARADO):
- Faixa Etária: $ageDesc
- Exposição Solar / Atividade ao Ar Livre: $outdoorDesc

DIRETRIZES DE PERSONALIZAÇÃO POR CONTEXTO:
- Se exposição for alta (esportes/sol frequente): na Rotina da Manhã, o protetor solar DEVE ser explicitamente "FPS 50+ toque seco com alta resistência à água e ao suor", prevenindo ardência nos olhos e perda de proteção durante treinos.
- Se faixa etária for >= 36 ou 50+: priorize ativos antioxidantes matinais (Vitamina C) e renovação noturna com suporte à barreira cutânea (Niacinamida, Ácido Hialurônico, Peptídeos ou Bakuchiol).
- Se faixa etária for < 20: priorize controle de oleosidade jovem com gel suave (Ácido Salicílico 2% ou Niacinamida), evitando produtos agressivos que causem efeito rebote.

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
3. ☀️ Protetor Solar: [FPS 50+ Toque Seco / Oil-Free — adequado para seu nível de exposição solar!]

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

    if (_proxyUrl.isNotEmpty) {
      final res = await http.post(
        Uri.parse(_proxyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task': 'report',
          'prompt': prompt,
        }),
      );
      if (res.statusCode != 200) {
        throw Exception('Erro ao gerar relatório no servidor de IA.');
      }
      final bodyJson = jsonDecode(res.body);
      return bodyJson['output'] as String? ?? 'Erro ao gerar relatório.';
    }

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

  static String _formatAgeDescription(String? age) {
    switch (age) {
      case 'under_20':
        return '< 20 anos (Jovem / Adolescente)';
      case '20_35':
        return '20 a 35 anos (Jovem adulto / Equilíbrio e prevenção)';
      case '36_50':
        return '36 a 50 anos (Maturidade inicial / Prevenção de manchas e firmeza)';
      case '50_plus':
        return 'Mais de 50 anos (Pele madura / Hidratação profunda e barreira)';
      default:
        return 'Não informada (faixa padrão 20-35 anos)';
    }
  }

  static String _formatOutdoorDescription(String? outdoor) {
    switch (outdoor) {
      case 'outdoor_high':
        return 'Alta exposição solar (pratica esportes ao ar livre, praia ou exposição diária frequente)';
      case 'outdoor_moderate':
        return 'Exposição solar moderada (finais de semana, trajetos e lazer)';
      case 'outdoor_low':
        return 'Baixa exposição solar (ambiente fechado, escritório / home office preponderante)';
      default:
        return 'Moderada (padrão rotina mista brasileira)';
    }
  }
}
