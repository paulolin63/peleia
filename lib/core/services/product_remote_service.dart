// ============================================================
//  lib/core/services/product_remote_service.dart
//
//  Serviço para carregar produtos dinamicamente da nuvem (JSON remoto)
//  com cache offline em SharedPreferences.
// ============================================================
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/scan/data/skin_analysis_result.dart';

class ProductRemoteService {
  static const String _cacheKey = 'peleia_cached_products_json';
  static const String _lastUpdateKey = 'peleia_products_last_update';

  /// Inicializa o catálogo: lê cache local primeiro e depois atualiza da nuvem
  static Future<void> syncProducts() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Carrega do cache local imediato
    final cachedJson = prefs.getString(_cacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(cachedJson);
        final products = list
            .map((item) => AffiliateProduct.fromJson(item as Map<String, dynamic>))
            .toList();
        ProductCatalog.setProducts(products);
      } catch (e) {
        debugPrint('⚠️ Erro ao decodificar produtos do cache: $e');
      }
    }

    // 2. Busca versão mais recente na nuvem (sem travar a inicialização)
    try {
      final response = await http
          .get(Uri.parse(ProductCatalog.remoteUrl))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        final products = list
            .map((item) => AffiliateProduct.fromJson(item as Map<String, dynamic>))
            .toList();

        if (products.isNotEmpty) {
          ProductCatalog.setProducts(products);
          // Salva no cache local para uso offline
          await prefs.setString(_cacheKey, response.body);
          await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
          debugPrint('✅ Catálogo de produtos sincronizado da nuvem com sucesso! (${products.length} itens)');
        }
      }
    } catch (e) {
      // Se estiver offline ou URL não configurada, o app continua usando o cache/fallback perfeitamente
      debugPrint('ℹ️ Usando catálogo local/fallback (Sem conexão remota: $e)');
    }
  }
}
