// Web scan: gallery is the only capture path; same ScanNotifier pipeline.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../paywall/presentation/quota_upsell_dialog.dart';
import 'scan_provider.dart';

class WebTestScreen extends ConsumerWidget {
  const WebTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanProvider);

    ref.listen<ScanState>(scanProvider, (prev, next) {
      if (next.step == ScanStep.done && prev?.step != ScanStep.done) {
        context.push('/result');
      } else if (next.step == ScanStep.quotaBlocked &&
          prev?.step != ScanStep.quotaBlocked) {
        showQuotaUpsellDialog(
          context,
          message: next.errorMessage ?? '',
        );
      }
    });

    final loading = state.isLoading || state.step == ScanStep.capturing;

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
                ],
              ),
              Expanded(
                child: Center(
                  child: loading
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : state.step == ScanStep.error
                          ? Text(
                              state.errorMessage ?? 'Erro',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.4,
                                color: AppTheme.textPrimary,
                              ),
                            )
                          : const SizedBox.shrink(),
                ),
              ),
              if (!loading)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      if (state.step == ScanStep.error) {
                        ref.read(scanProvider.notifier).reset();
                      }
                      ref.read(scanProvider.notifier).pickFromGallery();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.textPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      state.step == ScanStep.error
                          ? 'Tentar de novo'
                          : 'Selecionar foto',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
