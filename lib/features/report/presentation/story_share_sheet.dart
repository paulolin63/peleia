// ============================================================
//  lib/features/report/presentation/story_share_sheet.dart
//
//  Gerador de Card 9:16 (1080x1920) para Instagram Stories e
//  WhatsApp Status com modo privado (sem foto) ou com selfie.
// ============================================================
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/report_export_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../scan/data/skin_analysis_result.dart';

class StoryShareSheet extends StatefulWidget {
  final int score;
  final String skinTypeLabel;
  final int oleosidade;
  final int acne;
  final int manchas;
  final int hidratacao;
  final List<AffiliateProduct> products;
  final Uint8List? selfieBytes;
  final bool isEn;

  const StoryShareSheet({
    super.key,
    required this.score,
    required this.skinTypeLabel,
    required this.oleosidade,
    required this.acne,
    required this.manchas,
    required this.hidratacao,
    required this.products,
    this.selfieBytes,
    this.isEn = false,
  });

  static Future<void> show({
    required BuildContext context,
    required int score,
    required String skinTypeLabel,
    required int oleosidade,
    required int acne,
    required int manchas,
    required int hidratacao,
    required List<AffiliateProduct> products,
    Uint8List? selfieBytes,
    bool isEn = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => StoryShareSheet(
        score: score,
        skinTypeLabel: skinTypeLabel,
        oleosidade: oleosidade,
        acne: acne,
        manchas: manchas,
        hidratacao: hidratacao,
        products: products,
        selfieBytes: selfieBytes,
        isEn: isEn,
      ),
    );
  }

  @override
  State<StoryShareSheet> createState() => _StoryShareSheetState();
}

class _StoryShareSheetState extends State<StoryShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _showSelfie = false; // Padrão: Modo Privado (sem expor rosto)
  bool _isSharing = false;

  String get _statusBadge {
    if (widget.isEn) {
      if (widget.score >= 85) return 'Radiant Skin';
      if (widget.score >= 70) return 'Balanced Skin';
      if (widget.score >= 55) return 'Evolving Routine';
      return 'Care Priority';
    }
    if (widget.score >= 85) return 'Pele Radiante';
    if (widget.score >= 70) return 'Pele Equilibrada';
    if (widget.score >= 55) return 'Em Evolução';
    return 'Foco em Cuidados';
  }

  IconData get _statusIcon {
    if (widget.score >= 85) return Icons.auto_awesome_rounded;
    if (widget.score >= 70) return Icons.eco_rounded;
    if (widget.score >= 55) return Icons.water_drop_rounded;
    return Icons.shield_outlined;
  }

  List<String> get _topBrands {
    final seen = <String>{};
    final result = <String>[];
    for (final p in widget.products) {
      final b = p.brand.trim();
      if (b.isNotEmpty && seen.add(b.toLowerCase())) {
        result.add(b);
        if (result.length >= 3) break;
      }
    }
    return result;
  }

  Future<void> _shareAsImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    HapticFeedback.mediumImpact();

    try {
      // Aguarda um frame caso o usuário tenha acabado de alternar o modo privado
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Card preview not ready');
      }

      // 360x640 * 3.0 = 1080x1920 Full HD 9:16
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        throw StateError('Could not encode PNG');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final caption = widget.isEn
          ? 'My skin scored ${widget.score}/100 on PeleIA! ✨ Check yours free on Google Play: https://play.google.com/store/apps/details?id=com.peleia.app'
          : 'Minha pele fez ${widget.score}/100 no PeleIA! ✨ Descubra seu score grátis na Google Play: https://play.google.com/store/apps/details?id=com.peleia.app';

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              pngBytes,
              mimeType: 'image/png',
              name: 'peleia_score_stories.png',
            ),
          ],
          fileNameOverrides: const ['peleia_score_stories.png'],
          text: caption,
          subject: widget.isEn
              ? 'My PeleIA Skin Score (${widget.score}/100)'
              : 'Meu Score de Pele PeleIA (${widget.score}/100)',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEn
                  ? 'Could not generate image right now. Sharing text instead.'
                  : 'Não foi possível gerar a imagem agora. Compartilhando resumo em texto.',
            ),
            backgroundColor: AppTheme.primaryDark,
          ),
        );
      }
      await _shareAsText();
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _shareAsText() async {
    await ReportExportService.shareToSocial(
      score: widget.score,
      skinType: widget.skinTypeLabel,
      oleosidade: widget.oleosidade,
      acne: widget.acne,
      hidratacao: widget.hidratacao,
      products: widget.products,
      isEn: widget.isEn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.92;
    final hasSelfie = widget.selfieBytes != null && widget.selfieBytes!.isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: AppTheme.primaryDark,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEn
                            ? 'Stories & WhatsApp Card'
                            : 'Card para Stories & WhatsApp',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.isEn
                            ? 'Ready-to-post 9:16 score card (HD)'
                            : 'Formato 9:16 pronto para postar sem cortar',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Privacy mode toggle (only when selfie bytes are present)
            if (hasSelfie) ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    _buildPrivacyToggleChip(
                      label: widget.isEn ? '🙈 Private (no photo)' : '🙈 Modo Privado (sem foto)',
                      selected: !_showSelfie,
                      onTap: () => setState(() => _showSelfie = false),
                    ),
                    _buildPrivacyToggleChip(
                      label: widget.isEn ? '📸 Show selfie' : '📸 Com minha selfie',
                      selected: _showSelfie,
                      onTap: () => setState(() => _showSelfie = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 9:16 Story Card Preview (exact 360x640 logical canvas -> 1080x1920 @ 3x)
            Center(
              child: Container(
                width: 245,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F422D).withAlpha(65),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: _buildStoryCanvas(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Primary CTA: Share PNG Image
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareAsImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: _isSharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _isSharing
                      ? (widget.isEn ? 'Generating HD image...' : 'Gerando imagem HD...')
                      : (widget.isEn
                          ? 'Share Image (Stories)'
                          : 'Postar nos Stories / WhatsApp'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Secondary CTA: Share Text Only
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _isSharing ? null : _shareAsText,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.notes_rounded, size: 16, color: AppTheme.primary),
                label: Text(
                  widget.isEn ? 'Share summary as text' : 'Compartilhar apenas texto',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyToggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!selected) {
            HapticFeedback.selectionClick();
            onTap();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(12),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppTheme.primaryDark : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Fixed 360x640 canvas rendered at 3x -> 1080x1920 Full HD 9:16 PNG.
  Widget _buildStoryCanvas() {
    final brands = _topBrands;
    final showPhoto = _showSelfie &&
        widget.selfieBytes != null &&
        widget.selfieBytes!.isNotEmpty;

    return MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Container(
        width: 360,
        height: 640,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A3A28),
              Color(0xFF2D5E3C),
              Color(0xFF4F883B),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative warm peach glow (top-right)
            Positioned(
              top: -70,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.peach.withAlpha(90),
                      AppTheme.peach.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
            // Decorative soft botanical glow (bottom-left)
            Positioned(
              bottom: -60,
              left: -50,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryLight.withAlpha(95),
                      AppTheme.primaryLight.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Top Brand Bar ─────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withAlpha(160),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.5),
                          child: Image.asset(
                            'assets/icons/peleia-icon-512.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: AppTheme.primary,
                              child: Center(
                                child: Text('🌿', style: TextStyle(fontSize: 18)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'PeleIA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(32),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withAlpha(55)),
                            ),
                            child: Text(
                              widget.isEn ? 'AI SKIN CHECK' : 'SKINCARE IA',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                SizedBox(height: showPhoto ? 14 : 24),

                // ── Optional Selfie Avatar ─────────────────────
                if (showPhoto) ...[
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.peachLight, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.memory(
                        widget.selfieBytes!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Hero Score Ring ────────────────────────────
                SizedBox(
                  width: showPhoto ? 128 : 150,
                  height: showPhoto ? 128 : 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size.square(showPhoto ? 128 : 150),
                        painter: _StoryScoreRingPainter(
                          progress: (widget.score / 100.0).clamp(0.0, 1.0),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.score}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: showPhoto ? 42 : 50,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.isEn ? 'OUT OF 100' : 'DE 100 PTS',
                            style: TextStyle(
                              color: Colors.white.withAlpha(195),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Editorial Status Pill ──────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.peachSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon, size: 14, color: const Color(0xFF284B2F)),
                      const SizedBox(width: 5),
                      Text(
                        _statusBadge,
                        style: const TextStyle(
                          color: Color(0xFF284B2F),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  widget.isEn
                      ? 'SKIN TYPE · ${widget.skinTypeLabel.toUpperCase()}'
                      : 'PERFIL · PELE ${widget.skinTypeLabel.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withAlpha(225),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),

                const SizedBox(height: 18),

                // ── 2x2 Frosted Metric Cards ───────────────────
                Row(
                  children: [
                    Expanded(
                      child: _buildStoryMetricTile(
                        icon: Icons.opacity_rounded,
                        label: widget.isEn ? 'Oiliness' : 'Oleosidade',
                        score: widget.oleosidade,
                        higherIsBad: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStoryMetricTile(
                        icon: Icons.blur_on_rounded,
                        label: widget.isEn ? 'Acne/Pores' : 'Acne & Cravos',
                        score: widget.acne,
                        higherIsBad: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildStoryMetricTile(
                        icon: Icons.wb_sunny_outlined,
                        label: widget.isEn ? 'UV Spots' : 'Manchas UV',
                        score: widget.manchas,
                        higherIsBad: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStoryMetricTile(
                        icon: Icons.water_drop_outlined,
                        label: widget.isEn ? 'Hydration' : 'Hidratação',
                        score: widget.hidratacao,
                        higherIsBad: false,
                      ),
                    ),
                  ],
                ),

                if (brands.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(45)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.isEn
                                ? 'Matched: ${brands.join(' · ')}'
                                : 'Marcas indicadas: ${brands.join(' · ')}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // ── Viral CTA Footer ───────────────────────────
                Container(
                  height: 1,
                  width: double.infinity,
                  color: Colors.white.withAlpha(45),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isEn
                      ? 'What is your skin score?'
                      : 'Qual é o score da sua pele?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        size: 15,
                        color: Color(0xFF1F422D),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          widget.isEn
                              ? 'Free on Google Play · PeleIA'
                              : 'Baixe grátis na Google Play · PeleIA',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1F422D),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStoryMetricTile({
    required IconData icon,
    required String label,
    required int score,
    required bool higherIsBad,
  }) {
    final normalized = (score / 10.0).clamp(0.0, 1.0);
    Color barColor;
    if (higherIsBad) {
      if (score >= 7) {
        barColor = const Color(0xFFFF8A80);
      } else if (score >= 4) {
        barColor = const Color(0xFFFFD180);
      } else {
        barColor = const Color(0xFFA5F3B5);
      }
    } else {
      if (score >= 7) {
        barColor = const Color(0xFFA5F3B5);
      } else if (score >= 4) {
        barColor = const Color(0xFFFFD180);
      } else {
        barColor = const Color(0xFFFF8A80);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13.5, color: barColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withAlpha(220),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$score/10',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 5,
              backgroundColor: Colors.white.withAlpha(45),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryScoreRingPainter extends CustomPainter {
  final double progress;

  const _StoryScoreRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 14) / 2;

    final trackPaint = Paint()
      ..color = Colors.white.withAlpha(45)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final activePaint = Paint()
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        transform: GradientRotation(-math.pi / 2),
        colors: [
          Color(0xFFA5F3B5),
          Color(0xFFF9DFD2),
          Color(0xFFEAA07A),
          Color(0xFFA5F3B5),
        ],
      ).createShader(rect)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StoryScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
