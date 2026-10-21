// ============================================================
//  lib/core/services/history_service.dart
//
//  Gerenciador do histórico de análises e evolução da pele
//  Salva no SharedPreferences local (offline-first)
// ============================================================
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/history/data/history_entry.dart';
import '../../features/scan/data/skin_analysis_result.dart';

class HistoryService {
  static const String _storageKey = 'peleia_skin_history_entries_v1';
  static const int _maxStoredEntries = 30; // Guarda até 30 análises

  /// Salva uma nova análise no histórico
  static Future<void> saveAnalysis({
    required SkinAnalysisRaw analysis,
    required String report,
    Uint8List? rawImageBytes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentEntries = await getEntries();

      // Comprime a imagem para miniatura leve (~250px) para não pesar o storage
      String? base64Thumb;
      if (rawImageBytes != null && rawImageBytes.isNotEmpty) {
        base64Thumb = _generateThumbnailBase64(rawImageBytes);
      }

      final newEntry = HistoryEntry(
        id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        skinType: analysis.skinType,
        scoreGeral: analysis.scoreGeral,
        oleosidade: analysis.scores.oleosidade,
        acne: analysis.scores.acneCravos,
        manchas: analysis.scores.manchasSolares,
        hidratacao: analysis.scores.hidratacao,
        imageBase64: base64Thumb,
        reportSnippet: report.length > 200 ? report.substring(0, 200) : report,
      );

      // Insere no início (mais recente primeiro)
      final updatedList = [newEntry, ...currentEntries];
      if (updatedList.length > _maxStoredEntries) {
        updatedList.removeRange(_maxStoredEntries, updatedList.length);
      }

      final jsonString = jsonEncode(updatedList.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
      debugPrint('📈 Análise salva no histórico com sucesso! (Total: ${updatedList.length})');
    } catch (e) {
      debugPrint('⚠️ Erro ao salvar histórico: $e');
    }
  }

  /// Recupera todas as análises salvas (mais recente primeiro)
  static Future<List<HistoryEntry>> getEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((item) => HistoryEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Erro ao ler histórico: $e');
      return [];
    }
  }

  /// Remove uma entrada específica do histórico
  static Future<void> deleteEntry(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getEntries();
      list.removeWhere((e) => e.id == id);
      final jsonString = jsonEncode(list.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('⚠️ Erro ao deletar entrada do histórico: $e');
    }
  }

  /// Comprime a foto original para miniatura base64 de ~15KB
  static String? _generateThumbnailBase64(Uint8List originalBytes) {
    try {
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) return null;

      // Reduz para largura de 280px (suficiente para comparação na tela do celular)
      final thumbnail = img.copyResize(
        decoded,
        width: 280,
        interpolation: img.Interpolation.linear,
      );

      final jpgBytes = img.encodeJpg(thumbnail, quality: 65);
      return base64Encode(jpgBytes);
    } catch (_) {
      return null;
    }
  }
}
