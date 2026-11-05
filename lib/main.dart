// ============================================================
//  lib/main.dart
//  PeleIA — Entry point
// ============================================================
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Config via --dart-define / --dart-define-from-file=.env (never ship .env as asset).

  // Força orientação portrait (selfie) — só funciona em mobile
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await EvolutionReminderService.instance.initialize();
  }

  // Configura status bar transparente e ícones escuros para tema botânico claro
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // Inicializa RevenueCat (só Android/iOS, ignorado no Web automaticamente)
  await RevenueCatService.initialize();

  // Identidade do Firebase (uid compartilhado com o Worker e o RevenueCat).
  await AuthService.idToken();

  // Config remota: asset, cache e rede. Não bloqueia a abertura se a rede falhar.
  RemoteConfigService.load();

  runApp(
    const ProviderScope(
      child: PeleIAApp(),
    ),
  );
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
