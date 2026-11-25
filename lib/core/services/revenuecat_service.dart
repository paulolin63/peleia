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

  static Future<void>? _initFuture;
  static bool _configured = false;

  static Future<void> initialize() {
    // RevenueCat só funciona em Android/iOS — nunca em Web ou macOS desktop
    if (kIsWeb || !_isMobile || _configured) return Future.value();
    return _initFuture ??= _doInitialize();
  }

  static Future<void> _doInitialize() async {
    final apiKey = EnvValues.revenueCatAndroidKey;
    if (apiKey.isEmpty || apiKey == 'sua_chave_revenuecat_aqui' || apiKey.startsWith('sua_')) {
      debugPrint('ℹ️ RevenueCat API key vazia ou placeholder. Ignorando inicialização.');
      return;
    }

    try {
      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration).timeout(const Duration(seconds: 6));
      _configured = true;
      debugPrint('✅ RevenueCat inicializado com sucesso.');
    } catch (e, stack) {
      _initFuture = null;
      debugPrint('⚠️ Erro ao inicializar Purchases.configure(): $e\n$stack');
    }
  }

  static Future<bool> ensureInitialized() async {
    if (kIsWeb || !_isMobile) return false;
    if (_configured) return true;
    try {
      await initialize().timeout(const Duration(seconds: 6));
    } catch (_) {}
    return _configured;
  }

  static bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static Future<bool> isPremium() async {
    if (!await ensureInitialized()) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo().timeout(const Duration(seconds: 5));
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar status Premium no RevenueCat: $e');
      return false;
    }
  }

  static Future<List<Package>> getPackages() async {
    if (!await ensureInitialized()) return [];
    try {
      final offerings = await Purchases.getOfferings().timeout(const Duration(seconds: 8));
      return offerings.current?.availablePackages ?? [];
    } catch (e) {
      debugPrint('⚠️ Erro ao buscar pacotes no RevenueCat: $e');
      return [];
    }
  }

  /// Fallback direto na Google Play via RevenueCat getProducts caso Offerings ainda esteja vazio.
  static Future<List<StoreProduct>> getDirectStoreProducts(
    List<String> subIds,
    List<String> inAppIds,
  ) async {
    if (!await ensureInitialized()) return [];
    final results = <String, StoreProduct>{};

    if (subIds.isNotEmpty) {
      try {
        final subs = await Purchases.getProducts(
          subIds,
          productCategory: ProductCategory.subscription,
        ).timeout(const Duration(seconds: 8));
        for (final p in subs) {
          results[p.identifier] = p;
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao buscar assinaturas diretas: $e');
      }
    }

    if (inAppIds.isNotEmpty) {
      try {
        final inApps = await Purchases.getProducts(
          inAppIds,
          productCategory: ProductCategory.nonSubscription,
        ).timeout(const Duration(seconds: 8));
        for (final p in inApps) {
          results[p.identifier] = p;
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao buscar produtos avulsos diretos: $e');
      }

      // Caso o pacote avulso tenha sido cadastrado como pré-pago em Assinaturas no Play Console
      final missingInApps = inAppIds
          .where((id) => !results.keys.any((k) => k == id || k.startsWith('$id:')))
          .toList();
      if (missingInApps.isNotEmpty) {
        try {
          final prepaid = await Purchases.getProducts(
            missingInApps,
            productCategory: ProductCategory.subscription,
          ).timeout(const Duration(seconds: 8));
          for (final p in prepaid) {
            results[p.identifier] = p;
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao buscar pré-pagos diretos: $e');
        }
      }
    }

    return results.values.toList();
  }

  static Future<bool> purchasePackage(Package package, {bool isConsumable = false}) async {
    if (!await ensureInitialized()) {
      throw const PurchaseFailureException('Loja indisponível no momento.');
    }
    return _executePurchase(
      PurchaseParams.package(package),
      isConsumable: isConsumable,
    );
  }

  static Future<bool> purchaseStoreProduct(
    StoreProduct product, {
    required bool isConsumable,
  }) async {
    if (!await ensureInitialized()) {
      throw const PurchaseFailureException('Loja indisponível no momento.');
    }
    return _executePurchase(
      PurchaseParams.storeProduct(product),
      isConsumable: isConsumable,
    );
  }

  static Future<bool> _executePurchase(
    PurchaseParams params, {
    required bool isConsumable,
  }) async {
    try {
      final result = await Purchases.purchase(params);
      if (isConsumable) return true;
      return result.customerInfo.entitlements.active.containsKey('premium') ||
          result.customerInfo.activeSubscriptions.isNotEmpty;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('ℹ️ Compra cancelada pelo usuário.');
        throw const PurchaseCancelledException();
      }
      debugPrint('❌ Erro no RevenueCat purchase: ${e.message} (code: ${e.code})');
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
    if (!await ensureInitialized()) return false;
    try {
      final customerInfo = await Purchases.restorePurchases().timeout(const Duration(seconds: 10));
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
