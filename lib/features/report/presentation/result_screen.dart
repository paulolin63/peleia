// Result: score first. Report/products folded. Back returns home.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/report_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../scan/presentation/scan_provider.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  void _back(BuildContext context, WidgetRef ref) {
    ref.read(scanProvider.notifier).reset();
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanProvider);
    final analysis = state.analysis;

    if (analysis == null) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
          child: Center(
            child: TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Voltar'),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back(context, ref);
      },
      child: Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _back(context, ref),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppTheme.textPrimary,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ReportExportService.shareToSocial(
                        score: analysis.scoreGeral,
                        skinType: analysis.skinType,
                        oleosidade: analysis.scores.oleosidade,
                        acne: analysis.scores.acneCravos,
                        hidratacao: analysis.scores.hidratacao,
                        products: state.products,
                        reportSnippet: state.report,
                      );
                    },
                    child: const Text(
                      'Compartilhar',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Text(
                    '${analysis.scoreGeral}',
                    style: const TextStyle(
                      fontSize: 72,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -2,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    analysis.skinType,
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _ScoreRow('Oleosidade', analysis.scores.oleosidade),
                  _ScoreRow('Acne', analysis.scores.acneCravos),
                  _ScoreRow('Manchas', analysis.scores.manchasSolares),
                  _ScoreRow('Hidratacao', analysis.scores.hidratacao),
                  _ScoreRow('Poros', analysis.scores.porosDilatados),
                  _ScoreRow('Sensibilidade', analysis.scores.sensibilidade),
                  if (state.report != null && state.report!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        title: const Text(
                          'Rotina',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              state.report!,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (state.products.isNotEmpty) ...[
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text(
                          'Produtos',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        children: [
                          for (final p in state.products)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(p.name),
                              subtitle: Text(p.brand),
                              trailing: const Icon(Icons.open_in_new, size: 16),
                              onTap: () async {
                                final uri = Uri.tryParse(p.affiliateUrl);
                                if (uri != null) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => _back(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.textPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Concluir',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int value;
  const _ScoreRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
