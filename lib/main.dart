// ============================================================
//  lib/main.dart
//  PeleIA — Entry point
// ============================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/remote_config_service.dart';
import 'core/localization/app_translations.dart';
import 'core/services/auth_service.dart';
import 'core/services/evolution_reminder_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/revenuecat_service.dart';

Future<void> _warmUpServices() async {
  try {
    if (!kIsWeb) {
      unawaited(EvolutionReminderService.instance.initialize());
    }
    // Inicializa RevenueCat (protegido contra exceções para não abortar o bootstrap)
    try {
      await RevenueCatService.initialize();
    } catch (e, stack) {
      debugPrint('⚠️ Erro ao inicializar RevenueCat no bootstrap: $e\n$stack');
    }
    // Config local imediata + refresh em background
    unawaited(RemoteConfigService.load());
    // Identidade do Firebase (uid compartilhado com o Worker e o RevenueCat) sem travar a tela inicial.
    await AuthService.idToken();
  } catch (e) {
    debugPrint('⚠️ Warm-up em background falhou: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Força orientação portrait (selfie) — com timeout de segurança para nunca travar o Frame 1
  if (!kIsWeb) {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]).timeout(const Duration(seconds: 1));
    } catch (_) {}
  }

  // Configura status bar transparente e ícones escuros para tema botânico claro
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Renderiza imediatamente o Frame 1 (<100ms) sem aguardar chamadas de rede no boot
  runApp(
    const ProviderScope(
      child: PeleIAApp(),
    ),
  );

  unawaited(_warmUpServices());
}

class PeleIAApp extends ConsumerWidget {
  const PeleIAApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final lang = ref.watch(appLanguageProvider);
    final locale = lang == AppLanguage.en ? const Locale('en', 'US') : const Locale('pt', 'BR');

    return MaterialApp.router(
      title: 'PeleIA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      locale: locale,
    );
  }
}
