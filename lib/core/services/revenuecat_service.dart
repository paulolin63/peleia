// ============================================================
//  lib/core/services/revenuecat_service.dart
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/env_values.dart';

class PurchaseCancelledException implements Exception {
  final String message;
  const PurchaseCancelledException([this.message = 'Compra cancelada pelo usuário.']);
  @override
  String toString() => message;
}

class PurchaseFailureException implements Exception {
  final String message;
  final String? code;
  const PurchaseFailureException(this.message, {this.code});
  @override
  String toString() => message;
}

class RevenueCatService {
  static const String _weeklyId = 'peleia_weekly_990';
  static const String _monthlyId = 'peleia_monthly_1990';
  static const String _annualId = 'peleia_annual_8990';

  static Future<void> initialize() async {
    // RevenueCat só funciona em Android/iOS — nunca em Web ou macOS desktop
    if (kIsWeb || !_isMobile) return;

    final apiKey = EnvValues.revenueCatAndroidKey;
    if (apiKey.isEmpty) {
      debugPrint('ℹ️ RevenueCat API key vazia (dev mode). Ignorando inicialização.');
      return;
    }

    try {
      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      debugPrint('✅ RevenueCat inicializado com sucesso.');
    } catch (e, stack) {
      debugPrint('⚠️ Erro ao inicializar Purchases.configure(): $e\n$stack');
    }
  }

  static bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static Future<bool> isPremium() async {
    if (kIsWeb || !_isMobile) return false; // Web = tudo liberado para teste
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar status Premium no RevenueCat: $e');
      return false;
    }
  }

  static Future<List<Package>> getPackages() async {
    if (kIsWeb || !_isMobile) return [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (e) {
      debugPrint('⚠️ Erro ao buscar pacotes no RevenueCat: $e');
      return [];
    }
  }

  static Future<bool> purchasePackage(Package package) async {
    if (kIsWeb || !_isMobile) return false;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo.entitlements.active.containsKey('premium');
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('ℹ️ Compra cancelada pelo usuário.');
        throw const PurchaseCancelledException();
      }
      debugPrint('❌ Erro no RevenueCat purchasePackage: ${e.message} (code: ${e.code})');
      throw PurchaseFailureException(
        e.message ?? 'Falha no processamento do pagamento pelo Google Play.',
        code: e.code,
      );
    } catch (e) {
      debugPrint('❌ Erro inesperado ao processar compra: $e');
      throw PurchaseFailureException('Erro inesperado ao processar compra: $e');
    }
  }

  static Future<bool> restorePurchases() async {
    if (kIsWeb || !_isMobile) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.active.containsKey('premium');
    } on PlatformException catch (e) {
      debugPrint('❌ Erro no RevenueCat restorePurchases: ${e.message} (code: ${e.code})');
      throw PurchaseFailureException(
        e.message ?? 'Falha ao restaurar compras anteriores.',
        code: e.code,
      );
    } catch (e) {
      debugPrint('❌ Erro inesperado ao restaurar compras: $e');
      throw PurchaseFailureException('Erro inesperado ao restaurar compras: $e');
    }
  }

  static String get weeklyProductId => _weeklyId;
  static String get monthlyProductId => _monthlyId;
  static String get annualProductId => _annualId;
}
