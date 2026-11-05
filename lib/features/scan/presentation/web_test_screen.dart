// Web / desktop: gallery-only entry that reuses ScanNotifier (same pipeline as mobile).
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/quota_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../paywall/presentation/quota_upsell_dialog.dart';
import 'scan_provider.dart';

class WebTestScreen extends ConsumerStatefulWidget {
  const WebTestScreen({super.key});

  @override
  ConsumerState<WebTestScreen> createState() => _WebTestScreenState();
}

class _WebTestScreenState extends ConsumerState<WebTestScreen> {
  Future<void> _handleQuotaBlocked(ScanState state) async {
    if (state.quotaReason == QuotaBlockReason.proDailyExceeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text(
            state.errorMessage ?? state.statusMessage,
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
        ),
      );
      return;
    }
    await showQuotaUpsellDialog(
      context,
      message: state.errorMessage ?? state.statusMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ScanState>(scanProvider, (prev, next) {
      if (next.step == ScanStep.done && prev?.step != ScanStep.done) {
        context.push('/result');
      } else if (next.step == ScanStep.quotaBlocked &&
          prev?.step != ScanStep.quotaBlocked) {
        _handleQuotaBlocked(next);
      }
    });

    final scan = ref.watch(scanProvider);
    final loading = scan.isLoading || scan.step == ScanStep.capturing;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('✨', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'PeleIA',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/history'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Text(
                        '📈 Evolução',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFE8C9A0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(),
              const SizedBox(height: 32),
              const Text(
                'Análise de pele',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecione uma foto de rosto (mesmo fluxo do app mobile).',
                style: TextStyle(fontSize: 14, color: Color(0xFF8A7A6E)),
              ),
              const SizedBox(height: 32),
              if (loading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        color: AppTheme.primary,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        scan.statusMessage.isNotEmpty
                            ? scan.statusMessage
                            : 'Processando...',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: () =>
                      ref.read(scanProvider.notifier).pickFromGallery(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC8714A), Color(0xFFE8A44A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      children: [
                        Text('📁', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 12),
                        Text(
                          'Selecionar foto do rosto',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (scan.step == ScanStep.error &&
                  (scan.errorMessage?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD96B6B).withAlpha(30),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFD96B6B).withAlpha(75),
                    ),
                  ),
                  child: Text(
                    scan.errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFD96B6B),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
