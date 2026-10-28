import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_config.dart';

/// Runtime quota mode. JSON keeps production values; this flag boosts free scans
/// during Play closed testing without editing config files.
///
/// - `closed_testing` / `development` → free_lifetime = 20
/// - `production` → free_lifetime = 1
///
/// Set via `.env` `PELEIA_ENV=` or `--dart-define=PELEIA_ENV=production`.
/// Default: debug/profile → closed_testing, release → production.
class PeleiaEnv {
  PeleiaEnv._();

  static const closedTestingFreeLifetime = 20;
  static const productionFreeLifetime = 1;

  static String get mode {
    var value = '';
    try {
      value = dotenv.env['PELEIA_ENV'] ?? '';
    } catch (_) {}
    if (value.isEmpty) {
      value = const String.fromEnvironment('PELEIA_ENV');
    }
    if (value.isEmpty) {
      value = kReleaseMode ? 'production' : 'closed_testing';
    }
    return value.trim().toLowerCase();
  }

  static bool get isClosedTesting =>
      mode == 'closed_testing' || mode == 'development';

  static int get freeLifetime =>
      isClosedTesting ? closedTestingFreeLifetime : productionFreeLifetime;

  static QuotaLimits applyQuota(QuotaLimits base) {
    if (base.freeLifetime == freeLifetime) return base;
    return QuotaLimits(
      freeLifetime: freeLifetime,
      proDaily: base.proDaily,
      sosCredits: base.sosCredits,
    );
  }
}
