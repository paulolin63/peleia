import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/profile/user_profile.dart';
import '../../core/theme/app_theme.dart';
import 'avoidance_fields.dart';

class _AgeOption {
  final String id;
  final String label;
  const _AgeOption(this.id, this.label);
}

class _OutdoorOption {
  final String id;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _OutdoorOption({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });
}

const _ageOptions = [
  _AgeOption('under_20', '< 20 anos'),
  _AgeOption('20_35', '20 a 35 anos'),
  _AgeOption('36_50', '36 a 50 anos'),
  _AgeOption('50_plus', 'Mais de 50 anos'),
];

const _outdoorOptions = [
  _OutdoorOption(
    id: 'outdoor_high',
    icon: Icons.wb_sunny_rounded,
    iconColor: AppTheme.gold,
    iconBg: AppTheme.peachSoft,
    title: 'Alta exposição solar',
    subtitle: 'Esportes ao ar livre, praia ou sol forte frequente',
  ),
  _OutdoorOption(
    id: 'outdoor_moderate',
    icon: Icons.directions_bike_rounded,
    iconColor: AppTheme.primary,
    iconBg: AppTheme.primarySoft,
    title: 'Exposição moderada',
    subtitle: 'Finais de semana, lazer e trajetos urbanos',
  ),
  _OutdoorOption(
    id: 'outdoor_low',
    icon: Icons.laptop_mac_rounded,
    iconColor: AppTheme.primaryDark,
    iconBg: AppTheme.surfaceMuted,
    title: 'Baixa exposição solar',
    subtitle: 'Rotina em ambientes fechados / home office',
  ),
];

/// Modal inferior rolável para editar preferências do usuário e acessar
/// controles de privacidade / exclusão de conta (LGPD), com barra fixa de salvar.
class ProfileSettingsSheet extends StatefulWidget {
  final UserProfile initialProfile;
  final String initialAgeGroup;
  final String initialOutdoorExposure;
  final AppConfig? config;
  final Future<void> Function(UserProfile updatedProfile) onSave;
  final VoidCallback onOpenPrivacyNotice;
  final VoidCallback onOpenWebDeletion;
  final VoidCallback onRequestDeleteAccount;

  const ProfileSettingsSheet({
    super.key,
    required this.initialProfile,
    required this.initialAgeGroup,
    required this.initialOutdoorExposure,
    required this.config,
    required this.onSave,
    required this.onOpenPrivacyNotice,
    required this.onOpenWebDeletion,
    required this.onRequestDeleteAccount,
  });

  @override
  State<ProfileSettingsSheet> createState() => _ProfileSettingsSheetState();
}

class _ProfileSettingsSheetState extends State<ProfileSettingsSheet> {
  late String _ageGroup;
  late String _outdoorExposure;
  late final Set<String> _avoid;
  late final Set<String> _conditions;
  late final TextEditingController _noteCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ageGroup = widget.initialAgeGroup;
    _outdoorExposure = widget.initialOutdoorExposure;
    _avoid = widget.initialProfile.avoidIngredients.toSet();
    _conditions = widget.initialProfile.conditions.toSet();
    _noteCtrl = TextEditingController(text: widget.initialProfile.note);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    final updated = widget.initialProfile.copyWith(
      ageGroup: _ageGroup,
      outdoorExposure: _outdoorExposure,
      avoidIngredients: _avoid.toList(),
      conditions: _conditions.toList(),
      note: _noteCtrl.text.trim(),
    );

    try {
      await widget.onSave(updated);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPinnedHeader(context),
              const Divider(height: 1, thickness: 1, color: AppTheme.border),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAgeSection(),
                      const SizedBox(height: 20),
                      _buildOutdoorSection(),
                      if (widget.config != null) ...[
                        const SizedBox(height: 22),
                        AvoidanceFields(
                          config: widget.config!,
                          avoid: _avoid,
                          conditions: _conditions,
                          note: _noteCtrl,
                          onChanged: setState,
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Divider(height: 1, color: AppTheme.border),
                      const SizedBox(height: 16),
                      _buildPrivacySection(),
                    ],
                  ),
                ),
              ),
              _buildStickyFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perfil & Configurações',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Personalize suas preferências ou gerencie sua conta (LGPD).',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Faixa Etária',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in _ageOptions)
              _ProfileChoiceChip(
                label: option.label,
                selected: _ageGroup == option.id,
                onTap: () => setState(() => _ageGroup = option.id),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutdoorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exposição Solar & Esportes ao Ar Livre',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _outdoorOptions.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _OutdoorRadioCard(
            option: _outdoorOptions[i],
            selected: _outdoorExposure == _outdoorOptions[i].id,
            onTap: () => setState(() => _outdoorExposure = _outdoorOptions[i].id),
          ),
        ],
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configurações & Privacidade (LGPD)',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Gerencie suas informações e controle a exclusão dos seus dados.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _SettingsActionTile(
          icon: Icons.shield_outlined,
          iconColor: AppTheme.primary,
          title: 'Aviso de Privacidade & Retenção de Dados',
          trailingIcon: Icons.chevron_right,
          trailingSize: 18,
          onTap: widget.onOpenPrivacyNotice,
        ),
        const SizedBox(height: 8),
        _SettingsActionTile(
          icon: Icons.open_in_browser,
          iconColor: AppTheme.textSecondary,
          title: 'Página Web de Exclusão de Conta (Google Play)',
          trailingIcon: Icons.open_in_new,
          trailingSize: 16,
          onTap: widget.onOpenWebDeletion,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: BorderSide(color: AppTheme.error.withAlpha(120)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: widget.onRequestDeleteAccount,
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text(
              'Excluir Conta e Dados',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline_rounded, size: 20),
          label: Text(
            _isSaving ? 'Salvando...' : 'Salvar Preferências',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _ProfileChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySoft : AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.primaryDark : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _OutdoorRadioCard extends StatelessWidget {
  final _OutdoorOption option;
  final bool selected;
  final VoidCallback onTap;

  const _OutdoorRadioCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySoft : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: option.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(option.icon, color: option.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    option.subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppTheme.primary : AppTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final IconData trailingIcon;
  final double trailingSize;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.trailingIcon,
    required this.trailingSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(trailingIcon, color: AppTheme.textMuted, size: trailingSize),
          ],
        ),
      ),
    );
  }
}
