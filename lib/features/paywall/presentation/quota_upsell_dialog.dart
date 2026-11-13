// Quota blocked: one primary path to Premium. SOS + Google folded.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

Future<void> showQuotaUpsellDialog(
  BuildContext context, {
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Limite atingido',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.textPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/premium');
            },
            child: const Text(
              'Premium',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.push('/premium?sos=1');
          },
          child: const Text(
            'So mais 1',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        if (!AuthService.isGoogleUser)
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final cred = await AuthService.signInWithGoogle();
                if (cred != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conta conectada.')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Falha ao entrar.')),
                  );
                }
              }
            },
            child: const Text(
              'Entrar com Google',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Fechar',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      ],
    ),
  );
}
