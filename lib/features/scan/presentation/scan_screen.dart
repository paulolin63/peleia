// Scan: one primary action (camera). Gallery + back are secondary.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/quota_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../paywall/presentation/quota_upsell_dialog.dart';
import 'scan_provider.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanProvider);

    ref.listen<ScanState>(scanProvider, (prev, next) {
      if (next.step == ScanStep.done && prev?.step != ScanStep.done) {
        context.push('/result');
      } else if (next.step == ScanStep.quotaBlocked &&
          prev?.step != ScanStep.quotaBlocked) {
        if (next.quotaReason == QuotaBlockReason.proDailyExceeded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.errorMessage ?? '')),
          );
        } else {
          showQuotaUpsellDialog(
            context,
            message: next.errorMessage ?? '',
          );
        }
      }
    });

    void goBack() {
      ref.read(scanProvider.notifier).reset();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack();
      },
      child: Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: goBack,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppTheme.textPrimary,
                  ),
                  const Spacer(),
                  if (!state.isLoading)
                    TextButton(
                      onPressed: () =>
                          ref.read(scanProvider.notifier).pickFromGallery(),
                      child: const Text(
                        'Galeria',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                ],
              ),
              Expanded(child: _body(state)),
              if (!state.isLoading && state.step != ScanStep.error)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () =>
                        ref.read(scanProvider.notifier).captureAndAnalyze(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.textPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Tirar selfie',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (state.step == ScanStep.error) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      ref.read(scanProvider.notifier).reset();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.textPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Tentar de novo'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _body(ScanState state) {
    if (state.isLoading || state.step == ScanStep.capturing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            if (state.statusMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                state.statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (state.step == ScanStep.error) {
      return Center(
        child: Text(
          state.errorMessage ?? 'Erro',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            height: 1.4,
          ),
        ),
      );
    }

    return const SizedBox.expand();
  }
}
