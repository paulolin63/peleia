import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown when free/SOS quota is exhausted. SOS = impulse, Pro = habit.
Future<void> showQuotaUpsellDialog(
  BuildContext context, {
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1C1712),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Continue sua evolução',
        style: TextStyle(
          color: Color(0xFFF5F0EC),
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
            style: const TextStyle(color: Color(0xFFE8C9A0), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Quer só mais uma análise agora, ou acompanhar a pele semana a semana?',
            style: TextStyle(color: Color(0xFF8A7A6E), fontSize: 13, height: 1.4),
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
              backgroundColor: const Color(0xFFC8714A),
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
              foregroundColor: const Color(0xFFE8C9A0),
              side: const BorderSide(color: Color(0xFFC8714A)),
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
          child: const Text('Agora não', style: TextStyle(color: Color(0xFF8A7A6E))),
        ),
      ],
    ),
  );
}
