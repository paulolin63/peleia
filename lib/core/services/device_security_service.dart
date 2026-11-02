// ============================================================
//  lib/core/services/device_security_service.dart
//
//  Identificação e ancoragem de hardware para prevenção de fraudes:
//  - Gera fingerprint estável baseado nas propriedades do aparelho
//  - Impede que usuários limpem dados/reinstalem para burlar cotas
// ============================================================
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceSecurityService {
  static const String _prefKey = 'peleia_device_fingerprint_v1';
  static String? _cachedFingerprint;

  @visibleForTesting
  static void resetForTesting() {
    _cachedFingerprint = null;
  }

  /// Retorna o hash SHA-256 único e consistente deste dispositivo.
  static Future<String> getDeviceFingerprint() async {
    if (_cachedFingerprint != null && _cachedFingerprint!.isNotEmpty) {
      return _cachedFingerprint!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && saved.isNotEmpty) {
        _cachedFingerprint = saved;
        return saved;
      }

      String seed = '';
      final deviceInfo = DeviceInfoPlugin();

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final android = await deviceInfo.androidInfo;
        seed = 'android:${android.id}:${android.model}:${android.brand}:${android.hardware}:${android.manufacturer}';
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await deviceInfo.iosInfo;
        seed = 'ios:${ios.identifierForVendor ?? ios.model}:${ios.utsname.machine}';
      } else {
        seed = 'fallback:${DateTime.now().millisecondsSinceEpoch}:${prefs.hashCode}';
      }

      final hash = sha256.convert(utf8.encode(seed)).toString();
      await prefs.setString(_prefKey, hash);
      _cachedFingerprint = hash;
      return hash;
    } catch (e) {
      debugPrint('[DeviceSecurityService] Falha ao coletar hardware info: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(_prefKey);
        if (saved != null && saved.isNotEmpty) {
          _cachedFingerprint = saved;
          return saved;
        }
        final fallbackHash = sha256.convert(utf8.encode('fallback:${DateTime.now().microsecondsSinceEpoch}')).toString();
        await prefs.setString(_prefKey, fallbackHash);
        _cachedFingerprint = fallbackHash;
        return fallbackHash;
      } catch (_) {
        final fallbackHash = sha256.convert(utf8.encode('fallback:${DateTime.now().microsecondsSinceEpoch}')).toString();
        _cachedFingerprint = fallbackHash;
        return fallbackHash;
      }
    }
  }
}
