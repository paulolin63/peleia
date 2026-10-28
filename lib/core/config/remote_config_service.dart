import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';
import 'peleia_env.dart';
import '../services/quota_service.dart';

class RemoteConfigService {
  static const _cacheKey = 'peleia_remote_config_json';
  static const _etagKey = 'peleia_remote_config_etag';
  static const _fetchedAtKey = 'peleia_remote_config_fetched_at';
  static const _assetPath = 'assets/config/peleia_config.json';
  static const _maxAge = Duration(hours: 1);

  static AppConfig? current;

  static Future<AppConfig> load({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    AppConfig? resolved = await _fromAsset();

    final cachedRaw = prefs.getString(_cacheKey);
    final cached = _parse(cachedRaw);
    if (cached != null) resolved = cached;

    final fetchedAt = prefs.getInt(_fetchedAtKey) ?? 0;
    final stale = DateTime.now().millisecondsSinceEpoch - fetchedAt > _maxAge.inMilliseconds;
    if (force || stale) {
      final fresh = await _fromNetwork(prefs);
      if (fresh != null) resolved = fresh;
    }

    resolved ??= AppConfig.tryParse(const {'schema_version': 0});
    var config = resolved ?? _emptyFallback();
    config = config.copyWith(quota: PeleiaEnv.applyQuota(config.quota));
    current = config;
    QuotaService.applyLimits(config.quota);
    debugPrint('PELEIA_ENV=${PeleiaEnv.mode} free_lifetime=${config.quota.freeLifetime}');
    return config;
  }

  static Future<AppConfig?> _fromAsset() async {
    try {
      return _parse(await rootBundle.loadString(_assetPath));
    } catch (e) {
      debugPrint('Config embutida indisponível: $e');
      return null;
    }
  }

  static Future<AppConfig?> _fromNetwork(SharedPreferences prefs) async {
    final base = _proxyBase();
    if (base.isEmpty) return null;
    try {
      final etag = prefs.getString(_etagKey);
      final response = await http.get(
        Uri.parse('$base/config'),
        headers: {if (etag != null) 'If-None-Match': etag},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 304) {
        await prefs.setInt(_fetchedAtKey, DateTime.now().millisecondsSinceEpoch);
        return _parse(prefs.getString(_cacheKey));
      }
      if (response.statusCode != 200) return null;

      final parsed = _parse(response.body);
      if (parsed == null) {
        debugPrint('Config remota ignorada (esquema desconhecido ou inválida).');
        return null;
      }
      await prefs.setString(_cacheKey, response.body);
      final newEtag = response.headers['etag'];
      if (newEtag != null) await prefs.setString(_etagKey, newEtag);
      await prefs.setInt(_fetchedAtKey, DateTime.now().millisecondsSinceEpoch);
      return parsed;
    } catch (e) {
      debugPrint('Config remota indisponível, usando a última válida: $e');
      return null;
    }
  }

  static AppConfig? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AppConfig.tryParse(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static String _proxyBase() {
    var url = '';
    try {
      url = dotenv.env['GEMINI_PROXY_URL'] ?? '';
    } catch (_) {}
    if (url.isEmpty) url = const String.fromEnvironment('GEMINI_PROXY_URL');
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/config')) url = url.substring(0, url.length - '/config'.length);
    return url;
  }

  static AppConfig _emptyFallback() {
    return AppConfig.tryParse({
      'schema_version': 1,
      'config_version': 'fallback',
      'min_app_build': 1,
      'quota': {'free_lifetime': 1, 'pro_daily': 2, 'sos_credits': 3},
      'products': [
        {'id': 'fallback', 'name': 'Protetor solar FPS 50+', 'brand': '', 'active': true, 'category': 'protetor'},
      ],
    })!;
  }
}

final appConfigProvider = FutureProvider<AppConfig>((ref) => RemoteConfigService.load());
