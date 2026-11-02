import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Shown when free/SOS quota is exhausted. SOS = impulse, Pro = habit.
Future<void> showQuotaUpsellDialog(
  BuildContext context, {
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Continue sua evolução',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Quer só mais uma análise agora, ou acompanhar a pele semana a semana?',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/premium?sos=1');
            },
            child: const Text(
              'Mais 1 análise agora (SOS)',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/premium');
            },
            child: const Text(
              'Ver PeleIA Pro',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Agora não', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    ),
  );
}
