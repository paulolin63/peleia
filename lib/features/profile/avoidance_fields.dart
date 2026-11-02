import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';

/// Chips de ingredientes e condições, mais a observação livre. A lista vem da config.
class AvoidanceFields extends StatelessWidget {
  final AppConfig config;
  final Set<String> avoid;
  final Set<String> conditions;
  final TextEditingController note;
  final void Function(VoidCallback fn) onChanged;

  const AvoidanceFields({
    super.key,
    required this.config,
    required this.avoid,
    required this.conditions,
    required this.note,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingredientes a evitar',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in config.ingredients)
              FilterChip(
                label: Text(option.label),
                selected: avoid.contains(option.id),
                onSelected: (selected) => onChanged(() {
                  if (selected) {
                    avoid.add(option.id);
                  } else {
                    avoid.remove(option.id);
                  }
                }),
                selectedColor: AppTheme.primarySoft,
                checkmarkColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: avoid.contains(option.id) ? AppTheme.primaryDark : AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: avoid.contains(option.id) ? FontWeight.w700 : FontWeight.w500,
                ),
                backgroundColor: AppTheme.surface,
                side: BorderSide(color: avoid.contains(option.id) ? AppTheme.primary : AppTheme.border),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Condições',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in config.conditions)
              FilterChip(
                label: Text(option.label),
                selected: conditions.contains(option.id),
                onSelected: (selected) => onChanged(() {
                  if (selected) {
                    conditions.add(option.id);
                  } else {
                    conditions.remove(option.id);
                  }
                }),
                selectedColor: AppTheme.primarySoft,
                checkmarkColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: conditions.contains(option.id) ? AppTheme.primaryDark : AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: conditions.contains(option.id) ? FontWeight.w700 : FontWeight.w500,
                ),
                backgroundColor: AppTheme.surface,
                side: BorderSide(color: conditions.contains(option.id) ? AppTheme.primary : AppTheme.border),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Observação pessoal',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: note,
          maxLength: 280,
          maxLines: 3,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Ex.: alergia à marca X, uso isotretinoína',
            hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            counterStyle: TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Isso fica no seu aparelho e só vai para a IA na hora de montar a rotina. Confira sempre o rótulo do produto.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4),
        ),
      ],
    );
  }
}
