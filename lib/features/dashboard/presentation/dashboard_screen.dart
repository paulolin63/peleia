// Home: purpose in 3s, one primary action. Secondary in overflow.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/history_service.dart';
import '../../../core/services/quota_service.dart';
import '../../../core/services/revenuecat_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../history/data/history_entry.dart';
import '../../profile/avoidance_fields.dart';
import '../../../core/profile/user_profile.dart';
import '../../../core/config/remote_config_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  HistoryEntry? _latest;
  bool _loading = true;
  bool _isPro = false;
  QuotaStatus? _quota;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final pro = await RevenueCatService.isPremium();
    final entries = await HistoryService.getEntries();
    final quota = await QuotaService.checkQuota(isPro: pro);
    if (!mounted) return;
    setState(() {
      _isPro = pro;
      _latest = entries.isEmpty ? null : entries.first;
      _quota = quota;
      _loading = false;
    });
  }

  Future<void> _openMore() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: const Text('Historico'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/history').then((_) => _reload());
                },
              ),
              ListTile(
                title: Text(_isPro ? 'Assinatura' : 'Premium'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/premium').then((_) => _reload());
                },
              ),
              ListTile(
                title: const Text('Perfil'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _editProfile();
                },
              ),
              ListTile(
                title: Text(
                  AuthService.isGoogleUser
                      ? (AuthService.userEmail ?? 'Conta Google')
                      : 'Entrar com Google',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (AuthService.isGoogleUser) return;
                  try {
                    final cred = await AuthService.signInWithGoogle();
                    if (!mounted) return;
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          cred != null ? 'Conta conectada.' : 'Login cancelado.',
                        ),
                      ),
                    );
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Falha ao entrar.')),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editProfile() async {
    final config = await RemoteConfigService.load();
    final profile = await UserProfileStore.load();
    final avoid = profile.avoidIngredients.toSet();
    final conditions = profile.conditions.toSet();
    final note = TextEditingController(text: profile.note);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> persist() async {
              await UserProfileStore.save(profile.copyWith(
                avoidIngredients: avoid.toList(),
                conditions: conditions.toList(),
                note: note.text,
              ));
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: AvoidanceFields(
                  config: config,
                  avoid: avoid,
                  conditions: conditions,
                  note: note,
                  onChanged: (fn) {
                    setModal(fn);
                    persist();
                  },
                ),
              ),
            );
          },
        );
      },
    );
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: _loading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'PeleIA',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _openMore,
                          icon: const Icon(Icons.more_horiz),
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (_latest == null)
                      const Text(
                        'Analise sua pele com uma selfie.',
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.3,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      )
                    else ...[
                      Text(
                        '${_latest!.scoreGeral}',
                        style: const TextStyle(
                          fontSize: 64,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -2,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _latest!.skinType,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (_quota != null && !_quota!.canScan) ...[
                      const SizedBox(height: 16),
                      Text(
                        _quota!.statusText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          if (_quota != null && !_quota!.canScan) {
                            context.push('/premium').then((_) => _reload());
                            return;
                          }
                          context.push('/scan').then((_) => _reload());
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
                          _latest == null ? 'Analisar' : 'Nova analise',
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
    );
  }
}
