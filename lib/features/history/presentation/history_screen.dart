// History: list of scores. Detail on tap. One back path.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/history_service.dart';
import '../../../core/services/report_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/history_entry.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<HistoryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await HistoryService.getEntries();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Apagar historico?'),
        content: const Text('Todas as analises neste aparelho serao removidas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Apagar',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HistoryService.clearAllHistory();
      await _load();
    }
  }

  void _openDetail(HistoryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (_, scroll) {
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${entry.scoreGeral}',
                  style: const TextStyle(
                    fontSize: 56,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -2,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${entry.skinType} · ${entry.formattedDate}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                _row('Oleosidade', entry.oleosidade),
                _row('Acne', entry.acne),
                _row('Manchas', entry.manchas),
                _row('Hidratacao', entry.hidratacao),
                if (entry.fullReport.isNotEmpty ||
                    entry.reportSnippet.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Theme(
                    data: Theme.of(ctx)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text(
                        'Rotina',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            entry.fullReport.isNotEmpty
                                ? entry.fullReport
                                : entry.reportSnippet,
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
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    ReportExportService.shareToSocial(
                      score: entry.scoreGeral,
                      skinType: entry.skinType,
                      oleosidade: entry.oleosidade,
                      acne: entry.acne,
                      hidratacao: entry.hidratacao,
                      products: entry.products,
                      reportSnippet: entry.reportSnippet,
                    );
                  },
                  child: const Text(
                    'Compartilhar',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _row(String label, int value) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppTheme.textPrimary,
                  ),
                  const Spacer(),
                  if (_entries.isNotEmpty)
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text(
                        'Apagar',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _entries.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhuma analise ainda.',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final e = _entries[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${e.scoreGeral}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${e.skinType} · ${e.formattedDate}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppTheme.textMuted,
                              ),
                              onTap: () => _openDetail(e),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
