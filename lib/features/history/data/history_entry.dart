// ============================================================
//  lib/features/history/data/history_entry.dart
//
//  Modelo de dados para o histórico de análises de pele
// ============================================================
import 'dart:convert';
import 'dart:typed_data';

import '../../scan/data/skin_analysis_result.dart';

class HistoryEntry {
  final String id;
  final DateTime date;
  final String skinType;
  final int scoreGeral;
  final int oleosidade;
  final int acne;
  final int manchas;
  final int hidratacao;
  final String? imageBase64; // Miniatura comprimida em Base64
  final String reportSnippet;
  final String fullReport;
  final List<AffiliateProduct> products;

  const HistoryEntry({
    required this.id,
    required this.date,
    required this.skinType,
    required this.scoreGeral,
    required this.oleosidade,
    required this.acne,
    required this.manchas,
    required this.hidratacao,
    this.imageBase64,
    required this.reportSnippet,
    this.fullReport = '',
    this.products = const [],
  });

  Uint8List? get imageBytes {
    if (imageBase64 == null || imageBase64!.isEmpty) return null;
    try {
      return base64Decode(imageBase64!);
    } catch (_) {
      return null;
    }
  }

  String get formattedDate {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    return '$d/$m/$y';
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      skinType: json['skin_type'] as String? ?? 'mista',
      scoreGeral: json['score_geral'] as int? ?? 70,
      oleosidade: json['oleosidade'] as int? ?? 5,
      acne: json['acne'] as int? ?? 4,
      manchas: json['manchas'] as int? ?? 3,
      hidratacao: json['hidratacao'] as int? ?? 6,
      imageBase64: json['image_base64'] as String?,
      reportSnippet: json['report_snippet'] as String? ?? '',
      fullReport: json['full_report'] as String? ?? (json['report_snippet'] as String? ?? ''),
      products: (json['products'] as List?)
              ?.map((item) => AffiliateProduct.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'skin_type': skinType,
    'score_geral': scoreGeral,
    'oleosidade': oleosidade,
    'acne': acne,
    'manchas': manchas,
    'hidratacao': hidratacao,
    'image_base64': imageBase64,
    'report_snippet': reportSnippet,
    'full_report': fullReport,
    'products': products.map((p) => p.toJson()).toList(),
  };
}
