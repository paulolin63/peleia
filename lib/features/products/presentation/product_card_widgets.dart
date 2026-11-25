// ============================================================
//  lib/features/products/presentation/product_card_widgets.dart
//
//  Componentes compartilhados de conversão para produtos afiliados:
//  - Seletor de faixa de orçamento (Todos / Econômica / Dermocosméticos)
//  - Thumbnail com foto remota opcional + packshot botânico por categoria
//  - Cards Hero e de Passo da Rotina com CTA claro de loja
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/recommendation.dart';
import '../../../core/theme/app_theme.dart';
import '../../scan/data/skin_analysis_result.dart';

class ProductBudgetFilterBar extends StatelessWidget {
  final ProductBudgetTier selected;
  final ValueChanged<ProductBudgetTier> onChanged;
  final bool isEn;

  const ProductBudgetFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.isEn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _buildChip(
            tier: ProductBudgetTier.all,
            icon: Icons.auto_awesome_rounded,
            label: isEn ? 'All' : 'Todos',
          ),
          _buildChip(
            tier: ProductBudgetTier.economica,
            icon: Icons.savings_outlined,
            label: isEn ? 'Value' : 'Econômica',
          ),
          _buildChip(
            tier: ProductBudgetTier.dermo,
            icon: Icons.workspace_premium_outlined,
            label: isEn ? 'Dermo' : 'Dermo',
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required ProductBudgetTier tier,
    required IconData icon,
    required String label,
  }) {
    final isSelected = selected == tier;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticFeedback.selectionClick();
            onChanged(tier);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(14),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13.5,
                color: isSelected ? AppTheme.primaryDark : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppTheme.primaryDark : AppTheme.textSecondary,
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

class ProductThumbnail extends StatelessWidget {
  final AffiliateProduct product;
  final double size;
  final double radius;

  const ProductThumbnail({
    super.key,
    required this.product,
    this.size = 60,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F0),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: _buildVisual(),
      ),
    );
  }

  Widget _buildVisual() {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Image.network(
        product.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildCategoryAssetOrEmoji(),
      );
    }
    return _buildCategoryAssetOrEmoji();
  }

  Widget _buildCategoryAssetOrEmoji() {
    final asset = product.categoryAssetPath;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Text(product.emoji, style: TextStyle(fontSize: size * 0.42)),
        ),
      );
    }
    return Center(
      child: Text(product.emoji, style: TextStyle(fontSize: size * 0.42)),
    );
  }
}

class StoreBadgePill extends StatelessWidget {
  final AffiliateProduct product;

  const StoreBadgePill({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final isMl = product.store.toLowerCase() == 'mercadolivre';
    final isAmazon = product.store.toLowerCase() == 'amazon';
    final bgColor = isMl
        ? const Color(0xFFFFF7CC)
        : isAmazon
            ? const Color(0xFFFFF3E0)
            : const Color(0xFFFFECE8);
    final borderColor = isMl
        ? const Color(0xFFE6CE5C)
        : isAmazon
            ? const Color(0xFFFFCC80)
            : const Color(0xFFF6B6A8);
    final textColor = isMl
        ? const Color(0xFF2D3277)
        : isAmazon
            ? const Color(0xFFB85D00)
            : const Color(0xFFD63918);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        product.storeLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class TierBadgePill extends StatelessWidget {
  final AffiliateProduct product;
  final bool isEn;

  const TierBadgePill({
    super.key,
    required this.product,
    this.isEn = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDermo = product.isDermo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isDermo ? const Color(0xFFFFF6E5) : AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDermo ? const Color(0xFFEBD0A0) : AppTheme.border,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDermo ? Icons.workspace_premium_rounded : Icons.eco_rounded,
            size: 11,
            color: isDermo ? const Color(0xFF8C5B12) : AppTheme.primaryDark,
          ),
          const SizedBox(width: 3),
          Text(
            isDermo
                ? 'Dermo'
                : (isEn ? 'Value' : 'Custo-benefício'),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: isDermo ? const Color(0xFF8C5B12) : AppTheme.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class HeroAffiliateProductCard extends StatelessWidget {
  final AffiliateProduct product;
  final String why;
  final VoidCallback onTap;
  final bool isEn;

  const HeroAffiliateProductCard({
    super.key,
    required this.product,
    required this.why,
    required this.onTap,
    this.isEn = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF6FBF3)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primary.withAlpha(90), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withAlpha(22),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 11, color: Colors.white),
                      const SizedBox(width: 3),
                      Text(
                        isEn ? 'TOP PICK' : 'PRIORIDADE',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    product.categoryStepLabel(isEn: isEn),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                TierBadgePill(product: product, isEn: isEn),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductThumbnail(product: product, size: 70, radius: 15),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            product.brand,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          StoreBadgePill(product: product),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.priceFormatted,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (why.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft.withAlpha(170),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 14,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        why,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryLight],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(55),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.storeActionCta(isEn: isEn),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoutineAffiliateProductCard extends StatelessWidget {
  final AffiliateProduct product;
  final VoidCallback onTap;
  final bool isEn;
  final bool compact;

  const RoutineAffiliateProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.isEn = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: compact ? 0 : 10),
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: compact ? AppTheme.bg : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: compact
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(5),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  product.categoryStepLabel(isEn: isEn),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                TierBadgePill(product: product, isEn: isEn),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ProductThumbnail(
                  product: product,
                  size: compact ? 52 : 58,
                  radius: 13,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            product.brand,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          StoreBadgePill(product: product),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            product.priceFormatted,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isEn ? 'Shop' : 'Ver oferta',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
