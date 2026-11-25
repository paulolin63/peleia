import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peleia/core/config/app_config.dart';
import 'package:peleia/core/profile/user_profile.dart';
import 'package:peleia/core/theme/app_theme.dart';
import 'package:peleia/features/profile/profile_settings_sheet.dart';

AppConfig _loadDiskConfig() {
  final raw = File('assets/config/peleia_config.json').readAsStringSync();
  final parsed = AppConfig.tryParse(jsonDecode(raw) as Map<String, dynamic>);
  if (parsed == null) {
    throw StateError('Failed to parse assets/config/peleia_config.json');
  }
  return parsed;
}

Widget _buildLauncherApp({
  required AppConfig config,
  required UserProfile initialProfile,
  required String initialAgeGroup,
  required String initialOutdoorExposure,
  required Future<void> Function(UserProfile updated) onSave,
  VoidCallback? onOpenPrivacyNotice,
  VoidCallback? onOpenWebDeletion,
  VoidCallback? onRequestDeleteAccount,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                isDismissible: true,
                isScrollControlled: true,
                backgroundColor: AppTheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => ProfileSettingsSheet(
                  initialProfile: initialProfile,
                  initialAgeGroup: initialAgeGroup,
                  initialOutdoorExposure: initialOutdoorExposure,
                  config: config,
                  onSave: onSave,
                  onOpenPrivacyNotice: onOpenPrivacyNotice ?? () {},
                  onOpenWebDeletion: onOpenWebDeletion ?? () {},
                  onRequestDeleteAccount: onRequestDeleteAccount ?? () {},
                ),
              );
            },
            child: const Text('Abrir Configurações'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late AppConfig diskConfig;

  setUpAll(() {
    diskConfig = _loadDiskConfig();
  });

  testWidgets(
    'Compact Phone 360x740: sticky Salvar Preferências immediately visible and saves changes without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      UserProfile? savedProfile;

      await tester.pumpWidget(
        _buildLauncherApp(
          config: diskConfig,
          initialProfile: const UserProfile(
            ageGroup: '20_35',
            outdoorExposure: 'outdoor_moderate',
          ),
          initialAgeGroup: '20_35',
          initialOutdoorExposure: 'outdoor_moderate',
          onSave: (updated) async {
            savedProfile = updated;
          },
        ),
      );

      await tester.tap(find.text('Abrir Configurações'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Perfil & Configurações'), findsOneWidget);
      expect(find.text('Salvar Preferências'), findsOneWidget);

      // Botão sticky já está visível e clicável na viewport sem precisar rolar
      final saveFinder = find.text('Salvar Preferências');
      expect(saveFinder.hitTestable(), findsOneWidget);

      await tester.tap(find.text('36 a 50 anos'));
      await tester.pump();
      await tester.tap(find.text('Alta exposição solar'));
      await tester.pump();

      await tester.tap(saveFinder);
      await tester.pumpAndSettle();

      expect(savedProfile, isNotNull);
      expect(savedProfile!.ageGroup, equals('36_50'));
      expect(savedProfile!.outdoorExposure, equals('outdoor_high'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Full vertical scroll reaches LGPD privacy and delete account controls on compact phone',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2220);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var privacyTapped = false;
      var webDeletionTapped = false;
      var deleteAccountTapped = false;

      await tester.pumpWidget(
        _buildLauncherApp(
          config: diskConfig,
          initialProfile: const UserProfile(
            ageGroup: '20_35',
            outdoorExposure: 'outdoor_moderate',
            note: 'Pele sensível ao sol',
          ),
          initialAgeGroup: '20_35',
          initialOutdoorExposure: 'outdoor_moderate',
          onSave: (_) async {},
          onOpenPrivacyNotice: () => privacyTapped = true,
          onOpenWebDeletion: () => webDeletionTapped = true,
          onRequestDeleteAccount: () => deleteAccountTapped = true,
        ),
      );

      await tester.tap(find.text('Abrir Configurações'));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Excluir Conta e Dados'),
        find.byType(SingleChildScrollView),
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Aviso de Privacidade & Retenção de Dados').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.text('Página Web de Exclusão de Conta (Google Play)').hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Excluir Conta e Dados').hitTestable(), findsOneWidget);

      await tester.tap(find.text('Aviso de Privacidade & Retenção de Dados'));
      await tester.pump();
      await tester.tap(find.text('Página Web de Exclusão de Conta (Google Play)'));
      await tester.pump();
      await tester.tap(find.text('Excluir Conta e Dados'));
      await tester.pump();

      expect(privacyTapped, isTrue);
      expect(webDeletionTapped, isTrue);
      expect(deleteAccountTapped, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
