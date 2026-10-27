// ============================================================
//  lib/core/services/revenuecat_service.dart
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static const String _weeklyId = 'peleia_weekly_990';
  static const String _monthlyId = 'peleia_monthly_1990';
  static const String _annualId = 'peleia_annual_8990';

  static Future<void> initialize() async {
    // RevenueCat só funciona em Android/iOS — nunca em Web ou macOS desktop
    if (kIsWeb || !_isMobile) return;

    final apiKey = dotenv.env['REVENUECAT_ANDROID_KEY'] ?? '';
    if (apiKey.isEmpty) return; // Dev mode sem RevenueCat

    final configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);
  }

  static bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static Future<bool> isPremium() async {
    if (kIsWeb || !_isMobile) return false; // Web = tudo liberado para teste
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (_) {
      return false;
    }
  }

  static Future<List<Package>> getPackages() async {
    if (kIsWeb || !_isMobile) return [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> purchasePackage(Package package) async {
    if (kIsWeb || !_isMobile) return false;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo.entitlements.active.containsKey('premium');
    } catch (e) {
      return false;
    }
  }

  static Future<bool> restorePurchases() async {
    if (kIsWeb || !_isMobile) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.active.containsKey('premium');
    } catch (_) {
      return false;
    }
  }

  static String get weeklyProductId => _weeklyId;
  static String get monthlyProductId => _monthlyId;
  static String get annualProductId => _annualId;
}
