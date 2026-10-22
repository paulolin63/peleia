// ============================================================
//  lib/main.dart
//  PeleIA — Entry point
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/remote_config_service.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/revenuecat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega variáveis de ambiente (.env) — ignora erro no web (não tem filesystem)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Web: usa variáveis embutidas ou deixa vazio (usuário configura depois)
  }

  // Força orientação portrait (selfie) — só funciona em mobile
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Configura status bar transparente
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
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

    return MaterialApp.router(
      title: 'PeleIA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      locale: const Locale('pt', 'BR'),
    );
  }
}
