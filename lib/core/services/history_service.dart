// ============================================================
//  lib/core/services/history_service.dart
//
//  Gerenciador do histórico de análises e evolução da pele
//  Salva no SharedPreferences local (offline-first)
// ============================================================
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/history/data/history_entry.dart';
import '../../features/scan/data/skin_analysis_result.dart';

import 'history_thumb_store.dart';
import 'privacy_service.dart';

class HistoryService {
  static const String _storageKey = 'peleia_skin_history_entries_v1';
  static const int _maxStoredEntries = 30; // Guarda até 30 análises

  /// Salva uma nova análise no histórico
  static Future<void> saveAnalysis({
    required SkinAnalysisRaw analysis,
    required String report,
    List<AffiliateProduct> products = const [],
    Uint8List? rawImageBytes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentEntries = await getEntries();

      final id = 'scan_${DateTime.now().millisecondsSinceEpoch}';
      String? imageFile;
      String? base64Thumb;
      final thumbBytes = _generateThumbnailBytes(rawImageBytes);
      if (thumbBytes != null) {
        imageFile = await HistoryThumbStore.save(id, thumbBytes);
        if (imageFile == null) {
          base64Thumb = base64Encode(thumbBytes);
        }
      }

      final newEntry = HistoryEntry(
        id: id,
        date: DateTime.now(),
        skinType: analysis.skinType,
        scoreGeral: analysis.scoreGeral,
        oleosidade: analysis.scores.oleosidade,
        acne: analysis.scores.acneCravos,
        manchas: analysis.scores.manchasSolares,
        hidratacao: analysis.scores.hidratacao,
        imageBase64: base64Thumb,
        imageFile: imageFile,
        reportSnippet: report.length > 200 ? report.substring(0, 200) : report,
        fullReport: report,
        products: products,
      );

      final updatedList = [newEntry, ...currentEntries];
      if (updatedList.length > _maxStoredEntries) {
        final removed = updatedList.sublist(_maxStoredEntries);
        updatedList.removeRange(_maxStoredEntries, updatedList.length);
        for (final entry in removed) {
          await HistoryThumbStore.delete(entry.imageFile);
        }
      }

      final jsonString = jsonEncode(updatedList.map((e) => e.toStorageJson()).toList());
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
      final entries = <HistoryEntry>[];
      for (final item in decoded) {
        var entry = HistoryEntry.fromJson(item as Map<String, dynamic>);
        if ((entry.imageBase64 == null || entry.imageBase64!.isEmpty) &&
            entry.imageFile != null) {
          final bytes = await HistoryThumbStore.load(entry.imageFile);
          if (bytes != null) {
            entry = entry.copyWith(imageBase64: base64Encode(bytes));
          }
        }
        entries.add(entry);
      }
      return entries;
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
      HistoryEntry? removed;
      list.removeWhere((e) {
        if (e.id == id) {
          removed = e;
          return true;
        }
        return false;
      });
      await HistoryThumbStore.delete(removed?.imageFile);
      final jsonString = jsonEncode(list.map((e) => e.toStorageJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('⚠️ Erro ao deletar entrada do histórico: $e');
    }
  }

  /// LGPD / Privacidade: Exclui permanentemente todo o histórico de fotos, arquivos e dados do usuário
  static Future<void> clearAllHistory() async {
    await PrivacyService.purgeAllUserData();
  }

  static Uint8List? _generateThumbnailBytes(Uint8List? originalBytes) {
    if (originalBytes == null || originalBytes.isEmpty) return null;
    try {
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) return null;

      final thumbnail = img.copyResize(
        decoded,
        width: 280,
        interpolation: img.Interpolation.linear,
      );

      return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 65));
    } catch (_) {
      return null;
    }
  }
}
