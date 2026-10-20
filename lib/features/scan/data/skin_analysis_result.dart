// ============================================================
//  lib/features/scan/data/skin_analysis_result.dart
//
//  Modelos de dados para o resultado da análise de pele
// ============================================================
import 'package:flutter/material.dart';

// ── Raw JSON from Gemini Vision ───────────────────────────
class SkinAnalysisRaw {
  final String skinType;
  final String tomDePele;
  final SkinScores scores;
  final List<String> problemasDetectados;
  final String urgenciaProtetorSolar;
  final int scoreGeral;
  final double confianca;
  final String observacaoClima;

  const SkinAnalysisRaw({
    required this.skinType,
    required this.tomDePele,
    required this.scores,
    required this.problemasDetectados,
    required this.urgenciaProtetorSolar,
    required this.scoreGeral,
    required this.confianca,
    required this.observacaoClima,
  });

  factory SkinAnalysisRaw.fromJson(Map<String, dynamic> json) {
    return SkinAnalysisRaw(
      skinType: json['skin_type'] as String? ?? 'mista',
      tomDePele: json['tom_de_pele'] as String? ?? 'media',
      scores: SkinScores.fromJson(
        json['scores'] as Map<String, dynamic>? ?? {},
      ),
      problemasDetectados: List<String>.from(
        json['problemas_detectados'] as List? ?? [],
      ),
      urgenciaProtetorSolar:
          json['urgencia_protetor_solar'] as String? ?? 'alta',
      scoreGeral: json['score_geral'] as int? ?? 70,
      confianca: (json['confianca'] as num?)?.toDouble() ?? 0.8,
      observacaoClima: json['observacao_clima'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'skin_type': skinType,
    'tom_de_pele': tomDePele,
    'scores': scores.toJson(),
    'problemas_detectados': problemasDetectados,
    'urgencia_protetor_solar': urgenciaProtetorSolar,
    'score_geral': scoreGeral,
    'confianca': confianca,
    'observacao_clima': observacaoClima,
  };

  // ── Helpers para UI ──────────────────────────────────────

  String get skinTypeLabel {
    const labels = {
      'oleosa': 'Pele Oleosa',
      'seca': 'Pele Seca',
      'mista': 'Pele Mista',
      'normal': 'Pele Normal',
      'sensivel': 'Pele Sensível',
    };
    return labels[skinType] ?? skinType;
  }

  Color get skinTypeColor {
    const colors = {
      'oleosa': Color(0xFFD96B6B),
      'seca': Color(0xFFE8A44A),
      'mista': Color(0xFFC8714A),
      'normal': Color(0xFF6AB187),
      'sensivel': Color(0xFFF2A58B),
    };
    return colors[skinType] ?? const Color(0xFFC8714A);
  }

  Color get scoreColor {
    if (scoreGeral >= 80) return const Color(0xFF6AB187);
    if (scoreGeral >= 60) return const Color(0xFFE8A44A);
    return const Color(0xFFD96B6B);
  }
}

// ── Scores individuais ────────────────────────────────────
class SkinScores {
  final int oleosidade;
  final int acneCravos;
  final int manchasSolares;
  final int sensibilidade;
  final int hidratacao;
  final int porosDilatados;

  const SkinScores({
    required this.oleosidade,
    required this.acneCravos,
    required this.manchasSolares,
    required this.sensibilidade,
    required this.hidratacao,
    required this.porosDilatados,
  });

  factory SkinScores.fromJson(Map<String, dynamic> json) {
    return SkinScores(
      oleosidade: json['oleosidade'] as int? ?? 5,
      acneCravos: json['acne_cravos'] as int? ?? 3,
      manchasSolares: json['manchas_solares'] as int? ?? 3,
      sensibilidade: json['sensibilidade'] as int? ?? 3,
      hidratacao: json['hidratacao'] as int? ?? 7,
      porosDilatados: json['poros_dilatados'] as int? ?? 4,
    );
  }

  Map<String, dynamic> toJson() => {
    'oleosidade': oleosidade,
    'acne_cravos': acneCravos,
    'manchas_solares': manchasSolares,
    'sensibilidade': sensibilidade,
    'hidratacao': hidratacao,
    'poros_dilatados': porosDilatados,
  };

  List<ScoreItem> get items => [
    ScoreItem(
      emoji: '🛢️',
      label: 'Oleosidade',
      score: oleosidade,
      higherIsBad: true,
    ),
    ScoreItem(
      emoji: '😤',
      label: 'Acne e Cravos',
      score: acneCravos,
      higherIsBad: true,
    ),
    ScoreItem(
      emoji: '☀️',
      label: 'Manchas Solares',
      score: manchasSolares,
      higherIsBad: true,
    ),
    ScoreItem(
      emoji: '💦',
      label: 'Hidratação',
      score: hidratacao,
      higherIsBad: false,
    ),
    ScoreItem(
      emoji: '🔴',
      label: 'Sensibilidade',
      score: sensibilidade,
      higherIsBad: true,
    ),
    ScoreItem(
      emoji: '⭕',
      label: 'Poros Dilatados',
      score: porosDilatados,
      higherIsBad: true,
    ),
  ];
}

// ── Item individual de score para UI ─────────────────────
class ScoreItem {
  final String emoji;
  final String label;
  final int score;
  final bool higherIsBad;

  const ScoreItem({
    required this.emoji,
    required this.label,
    required this.score,
    required this.higherIsBad,
  });

  double get normalized => score / 10.0;

  Color get color {
    if (higherIsBad) {
      if (score >= 7) return const Color(0xFFD96B6B);
      if (score >= 4) return const Color(0xFFE8A44A);
      return const Color(0xFF6AB187);
    } else {
      if (score >= 7) return const Color(0xFF6AB187);
      if (score >= 4) return const Color(0xFFE8A44A);
      return const Color(0xFFD96B6B);
    }
  }

  String get scoreLabel => '$score / 10';
}

// ── Produto afiliado para recomendação ───────────────────
class AffiliateProduct {
  final String name;
  final String brand;
  final String description;
  final double priceReais;
  final String store;        // 'shopee' | 'mercadolivre' | 'amazon'
  final String affiliateUrl;
  final String emoji;
  final List<String> forSkinTypes;  // Quais tipos de pele este produto serve

  const AffiliateProduct({
    required this.name,
    required this.brand,
    required this.description,
    required this.priceReais,
    required this.store,
    required this.affiliateUrl,
    required this.emoji,
    required this.forSkinTypes,
  });

  String get priceFormatted => 'R\$ ${priceReais.toStringAsFixed(2).replaceAll('.', ',')}';

  String get storeLabel {
    const labels = {
      'shopee': 'Shopee',
      'mercadolivre': 'Mercado Livre',
      'amazon': 'Amazon Brasil',
    };
    return labels[store] ?? store;
  }

  Color get storeColor {
    const colors = {
      'shopee': Color(0xFFEE4D2D),
      'mercadolivre': Color(0xFFFFE600),
      'amazon': Color(0xFFFF9900),
    };
    return colors[store] ?? const Color(0xFF6AB187);
  }
}

// ── Catálogo de produtos (Favoritos do Brasil) ───────
class ProductCatalog {
  static List<AffiliateProduct> getRecommendations(SkinAnalysisRaw analysis) {
    final List<AffiliateProduct> all = [
      // ── Limpeza ──────────────────────────────────────
      const AffiliateProduct(
        name: 'Actine Gel Dermatológico',
        brand: 'Darrow',
        description: 'Nº 1 mais prescrito no Brasil para pele oleosa e acneica',
        priceReais: 42.90,
        store: 'shopee',
        affiliateUrl: 'https://shopee.com.br/search?keyword=actine+darrow+gel',
        emoji: '🧴',
        forSkinTypes: ['oleosa', 'mista', 'acne', 'acne_ativa'],
      ),
      const AffiliateProduct(
        name: 'Salifast Gel de Limpeza (Ácido Salicílico 2%)',
        brand: 'Principia',
        description: 'Desobstrui poros e reduz cravos sem ressecar a pele',
        priceReais: 44.00,
        store: 'mercadolivre',
        affiliateUrl: 'https://lista.mercadolivre.com.br/principia-salifast',
        emoji: '🧼',
        forSkinTypes: ['oleosa', 'cravos', 'poros_dilatados'],
      ),
      const AffiliateProduct(
        name: 'Limpador Facial Suave',
        brand: 'Sallve',
        description: 'Gel-espuma hidratante com Niacinamida e Extrato de Camomila',
        priceReais: 54.90,
        store: 'amazon',
        affiliateUrl: 'https://www.amazon.com.br/s?k=sallve+limpador+facial',
        emoji: '🌿',
        forSkinTypes: ['normal', 'sensivel', 'seca', 'mista'],
      ),

      // ── Séruns e Tratamento ───────────────────────────
      const AffiliateProduct(
        name: 'Sérum Niacinamida 10% + Zinco (NC-01)',
        brand: 'Principia',
        description: 'O queridinho do Brasil para controlar brilho e manchas',
        priceReais: 54.00,
        store: 'shopee',
        affiliateUrl: 'https://shopee.com.br/search?keyword=principia+niacinamida',
        emoji: '✨',
        forSkinTypes: ['oleosa', 'mista', 'manchas_solares', 'poros_dilatados'],
      ),
      const AffiliateProduct(
        name: 'Sérum Vitamina C 10% (VC-10)',
        brand: 'Principia',
        description: 'Uniformiza o tom, combate manchas de sol e ilumina',
        priceReais: 59.00,
        store: 'mercadolivre',
        affiliateUrl: 'https://lista.mercadolivre.com.br/principia-vitamina-c',
        emoji: '🍋',
        forSkinTypes: ['manchas', 'manchas_solares', 'melasma', 'normal'],
      ),
      const AffiliateProduct(
        name: 'Sérum Antiacne com Ácido Salicílico',
        brand: 'Sallve',
        description: 'Secativo eficaz que acalma a vermelhidão sem descamar',
        priceReais: 64.90,
        store: 'amazon',
        affiliateUrl: 'https://www.amazon.com.br/s?k=sallve+serum+antiacne',
        emoji: '🎯',
        forSkinTypes: ['acne', 'acne_ativa', 'oleosidade_excessiva'],
      ),

      // ── Protetor Solar (Toque Seco BR) ────────────────
      const AffiliateProduct(
        name: 'Episol Sec FPS 60 Toque Seco',
        brand: 'Mantecorp',
        description: 'Protetor solar brasileiro clássico: efeito matte até no calor',
        priceReais: 68.90,
        store: 'amazon',
        affiliateUrl: 'https://www.amazon.com.br/s?k=episol+sec+fps+60',
        emoji: '☀️',
        forSkinTypes: ['oleosa', 'mista', 'acne'],
      ),
      const AffiliateProduct(
        name: 'Protetor Solar Toque Seco FPS 60',
        brand: 'Sallve',
        description: 'Defesa multivisível, sem resíduo esbranquiçado (ótimo para pele morena/negra)',
        priceReais: 64.90,
        store: 'mercadolivre',
        affiliateUrl: 'https://lista.mercadolivre.com.br/sallve-protetor-solar',
        emoji: '🌞',
        forSkinTypes: ['morena', 'negra', 'mista', 'sensivel'],
      ),
      const AffiliateProduct(
        name: 'Anthelios Airlicium FPS 70',
        brand: 'La Roche-Posay',
        description: 'Tecnologia que absorve a oleosidade e resiste ao suor tropical',
        priceReais: 89.90,
        store: 'shopee',
        affiliateUrl: 'https://shopee.com.br/search?keyword=anthelios+airlicium+70',
        emoji: '🛡️',
        forSkinTypes: ['oleosa', 'manchas_solares', 'melasma'],
      ),

      // ── Hidratantes Leves ─────────────────────────────
      const AffiliateProduct(
        name: 'Gel Hidratante Facial Ácido Hialurônico',
        brand: 'Needs',
        description: 'Super acessível da farmácia brasileira, textura aquosa gel',
        priceReais: 29.90,
        store: 'shopee',
        affiliateUrl: 'https://shopee.com.br/search?keyword=needs+gel+hidratante+facial',
        emoji: '💧',
        forSkinTypes: ['oleosa', 'mista', 'sensivel'],
      ),
      const AffiliateProduct(
        name: 'Loção Facial Hidratante com Ceramidas',
        brand: 'CeraVe',
        description: 'Restaura a barreira cutânea sem obstruir os poros',
        priceReais: 64.90,
        store: 'amazon',
        affiliateUrl: 'https://www.amazon.com.br/s?k=cerave+locao+facial',
        emoji: '🧴',
        forSkinTypes: ['seca', 'sensivel', 'normal'],
      ),
    ];

    // Filtro inteligente baseado no tipo de pele e problemas
    final relevant = all.where((p) {
      return p.forSkinTypes.any((type) =>
        type == analysis.skinType ||
        type == analysis.tomDePele ||
        analysis.problemasDetectados.any((prob) => prob.contains(type)),
      );
    }).toList();

    // Garante pelo menos um protetor solar essencial para o Brasil
    final hasSunscreen = relevant.any(
      (p) => p.description.toLowerCase().contains('protetor'),
    );
    if (!hasSunscreen) {
      relevant.add(all.firstWhere(
        (p) => p.emoji == '☀️' || p.emoji == '🌞',
        orElse: () => all[6],
      ));
    }

    // Retorna no máximo 4 produtos mais assertivos
    return relevant.take(4).toList();
  }
}
