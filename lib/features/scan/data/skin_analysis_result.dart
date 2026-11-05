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
      scoreGeral: _asInt(json['score_geral'], 70).clamp(0, 100),
      confianca: ((json['confianca'] as num?)?.toDouble() ?? 0.8).clamp(0.0, 1.0),
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
      oleosidade: _asScore(json['oleosidade'], 5),
      acneCravos: _asScore(json['acne_cravos'], 3),
      manchasSolares: _asScore(json['manchas_solares'], 3),
      sensibilidade: _asScore(json['sensibilidade'], 3),
      hidratacao: _asScore(json['hidratacao'], 7),
      porosDilatados: _asScore(json['poros_dilatados'], 4),
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

int _asInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  return fallback;
}

int _asScore(dynamic value, int fallback) => _asInt(value, fallback).clamp(0, 10);

// ── Produto afiliado para recomendação ───────────────────
class AffiliateProduct {
  final String id;
  final String name;
  final String brand;
  final String description;
  final String priceDisplay;  // Ex: "A partir de R$ 39" ou "~R$ 45"
  final double priceEstimated; // Para cálculos e ordenação
  final String store;         // 'shopee' | 'mercadolivre' | 'amazon'
  final String affiliateUrl;
  final String emoji;
  final List<String> forSkinTypes; // Tipos de pele alvo
  final String category;
  final List<String> ingredients;
  final int priority;
  final bool active;

  const AffiliateProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.description,
    required this.priceDisplay,
    required this.priceEstimated,
    required this.store,
    required this.affiliateUrl,
    required this.emoji,
    required this.forSkinTypes,
    this.category = '',
    this.ingredients = const [],
    this.priority = 0,
    this.active = true,
  });

  factory AffiliateProduct.fromJson(Map<String, dynamic> json) {
    return AffiliateProduct(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priceDisplay: json['price_display'] as String? ??
          'R\$ ${(json['price_estimated'] ?? 49.9).toStringAsFixed(2).replaceAll('.', ',')}',
      priceEstimated: (json['price_estimated'] as num?)?.toDouble() ?? 49.9,
      store: json['store'] as String? ?? 'shopee',
      affiliateUrl: json['affiliate_url'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '✨',
      forSkinTypes: List<String>.from(json['for_skin_types'] as List? ?? []),
      category: json['category'] as String? ?? '',
      ingredients: List<String>.from(json['ingredients'] as List? ?? []),
      priority: _asInt(json['priority'], 0),
      active: json['active'] is bool ? json['active'] as bool : true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'description': description,
    'price_display': priceDisplay,
    'price_estimated': priceEstimated,
    'store': store,
    'affiliate_url': affiliateUrl,
    'emoji': emoji,
    'for_skin_types': forSkinTypes,
    'category': category,
    'ingredients': ingredients,
    'priority': priority,
    'active': active,
  };

  String get priceFormatted => priceDisplay;

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
