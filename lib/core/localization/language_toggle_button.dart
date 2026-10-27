// ============================================================
//  lib/core/localization/language_toggle_button.dart
//
//  Botão pill compacto para alternar rapidamente entre PT e EN
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_translations.dart';

class LanguageToggleButton extends ConsumerWidget {
  final bool compact;
  const LanguageToggleButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final isEn = lang == AppLanguage.en;

    return Tooltip(
      message: isEn ? 'Mudar para Português' : 'Switch to English',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ref.read(appLanguageProvider.notifier).toggleLanguage(),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1712),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFC8714A).withAlpha(120),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC8714A).withAlpha(30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEn ? '🇺🇸' : '🇧🇷',
                  style: TextStyle(fontSize: compact ? 12 : 14),
                ),
                const SizedBox(width: 5),
                Text(
                  isEn ? 'EN' : 'PT',
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFF2A58B),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
