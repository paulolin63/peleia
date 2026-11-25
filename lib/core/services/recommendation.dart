import '../../features/scan/data/skin_analysis_result.dart';
import '../config/app_config.dart';
import '../profile/user_profile.dart';

enum ProductBudgetTier {
  all,
  economica,
  dermo,
}

class ProductRecommendation {
  final List<AffiliateProduct> products;
  final int hiddenCount;
  final bool missingSunscreen;
  final List<String> avoidedLabels;

  const ProductRecommendation({
    required this.products,
    required this.hiddenCount,
    required this.missingSunscreen,
    required this.avoidedLabels,
  });
}

/// Preferred marketplace order for affiliate coverage.
const kAffiliateStores = ['shopee', 'mercadolivre', 'amazon'];

/// Core 4-step daily skincare routine categories.
const kRoutineCategories = ['limpeza', 'serum', 'hidratante', 'protetor'];

bool _matchesBudgetTier(AffiliateProduct product, ProductBudgetTier tier) {
  switch (tier) {
    case ProductBudgetTier.all:
      return true;
    case ProductBudgetTier.economica:
      return product.isEconomica;
    case ProductBudgetTier.dermo:
      return product.isDermo;
  }
}

ProductRecommendation recommendProducts({
  required AppConfig config,
  required SkinAnalysisRaw analysis,
  required UserProfile profile,
  List<AffiliateProduct>? catalog,
  ProductBudgetTier budgetTier = ProductBudgetTier.all,
  int? maxProductsOverride,
}) {
  final avoided = profile.avoidedIds(config);
  final labels = profile.avoidedLabels(config);
  final note = _fold(profile.note);
  final maxProducts = maxProductsOverride ?? config.maxProducts;

  final all = (catalog ?? config.products.map(AffiliateProduct.fromJson).toList())
      .where((p) => p.active)
      .toList();

  bool excluded(AffiliateProduct product) {
    if (product.ingredients.any(avoided.contains)) return true;
    return _noteHits(product, note, config);
  }

  bool relevant(AffiliateProduct product) {
    return product.forSkinTypes.any((type) =>
        type == analysis.skinType ||
        type == analysis.tomDePele ||
        analysis.problemasDetectados
            .any((prob) => prob.contains(type) || type.contains(prob)));
  }

  final matching = all.where(relevant).toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));

  final hidden = matching.where(excluded).length;
  final eligibleAll = matching.where((p) => !excluded(p)).toList();

  // Filter by requested budget tier; fall back to full safe pool only if tier pool is completely empty.
  final eligibleTier = budgetTier == ProductBudgetTier.all
      ? eligibleAll
      : eligibleAll.where((p) => _matchesBudgetTier(p, budgetTier)).toList();
  final eligible = eligibleTier.isNotEmpty ? eligibleTier : eligibleAll;

  // Balance all 4 skincare steps first while maximizing multi-store affiliate coverage.
  final picked = _pickRoutineBalanced(eligible, maxProducts);

  var missingSunscreen = false;
  for (final category in config.requiredCategories) {
    final has = picked.any((p) => p.category == category);
    if (has) continue;

    final safeCategoryPool = all
        .where((p) => p.category == category && !excluded(p))
        .toList();
    final tierCategoryPool = budgetTier == ProductBudgetTier.all
        ? safeCategoryPool
        : safeCategoryPool.where((p) => _matchesBudgetTier(p, budgetTier)).toList();
    final candidates = (tierCategoryPool.isNotEmpty ? tierCategoryPool : safeCategoryPool)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    if (candidates.isEmpty) {
      if (category == 'protetor') missingSunscreen = true;
      continue;
    }

    // Prefer a candidate whose store is missing from the current pick.
    final presentStores = picked.map((p) => p.store.toLowerCase()).toSet();
    candidates.sort((a, b) {
      final aNew = presentStores.contains(a.store.toLowerCase()) ? 0 : 1;
      final bNew = presentStores.contains(b.store.toLowerCase()) ? 0 : 1;
      if (aNew != bNew) return bNew.compareTo(aNew);
      return b.priority.compareTo(a.priority);
    });

    if (picked.length >= maxProducts) {
      // Prefer dropping a duplicate-category item first, then duplicate-store, else last.
      final dupCatIdx = picked.lastIndexWhere(
        (p) => picked.where((x) => x.category == p.category).length > 1,
      );
      final dupStoreIdx = picked.lastIndexWhere(
        (p) => picked.where((x) => x.store == p.store).length > 1,
      );
      final dropIdx = dupCatIdx >= 0
          ? dupCatIdx
          : (dupStoreIdx >= 0 ? dupStoreIdx : picked.length - 1);
      picked.removeAt(dropIdx);
    }
    picked.add(candidates.first);
  }

  final ordered = _orderForDisplay(picked, analysis);

  return ProductRecommendation(
    products: ordered,
    hiddenCount: hidden,
    missingSunscreen: missingSunscreen,
    avoidedLabels: labels,
  );
}

/// Home/Dashboard curated list: respects avoided ingredients, budget tier,
/// 4-step category diversity, and multi-store affiliate diversity.
List<AffiliateProduct> pickBalancedHomeProducts({
  required AppConfig config,
  required UserProfile profile,
  ProductBudgetTier budgetTier = ProductBudgetTier.all,
  int maxProducts = 4,
}) {
  final avoided = profile.avoidedIds(config);
  final note = _fold(profile.note);

  bool excluded(AffiliateProduct product) {
    if (product.ingredients.any(avoided.contains)) return true;
    return _noteHits(product, note, config);
  }

  final safe = config.products
      .map(AffiliateProduct.fromJson)
      .where((p) => p.active && !excluded(p))
      .toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));

  final tierPool = budgetTier == ProductBudgetTier.all
      ? safe
      : safe.where((p) => _matchesBudgetTier(p, budgetTier)).toList();
  final pool = tierPool.isNotEmpty ? tierPool : safe;

  final picked = _pickRoutineBalanced(pool, maxProducts);
  picked.sort((a, b) {
    final orderCmp = a.routineOrder.compareTo(b.routineOrder);
    if (orderCmp != 0) return orderCmp;
    return b.priority.compareTo(a.priority);
  });
  return picked;
}

/// Picks 1 best product per core routine step (processing scarcest categories first
/// to maximize multi-store coverage), then fills remaining slots without over-stacking
/// any single category.
List<AffiliateProduct> _pickRoutineBalanced(
  List<AffiliateProduct> eligible,
  int maxProducts,
) {
  if (eligible.isEmpty || maxProducts <= 0) return [];

  final byCategory = <String, List<AffiliateProduct>>{};
  for (final p in eligible) {
    final cat = p.category.toLowerCase();
    byCategory.putIfAbsent(cat, () => []).add(p);
  }

  final picked = <AffiliateProduct>[];
  final seenIds = <String>{};
  final presentStores = <String>{};
  final categoryCounts = <String, int>{};

  // Sort core categories by fewest distinct available stores first (most constrained first),
  // so scarce categories lock in their store and flexible categories fill missing stores.
  final availableCoreCats = kRoutineCategories
      .where((c) => (byCategory[c]?.isNotEmpty ?? false))
      .toList()
    ..sort((a, b) {
      final storesA = byCategory[a]!.map((p) => p.store.toLowerCase()).toSet().length;
      final storesB = byCategory[b]!.map((p) => p.store.toLowerCase()).toSet().length;
      if (storesA != storesB) return storesA.compareTo(storesB);
      return byCategory[b]!.first.priority.compareTo(byCategory[a]!.first.priority);
    });

  // Pass 1: 1 best product per core routine category.
  for (final cat in availableCoreCats) {
    if (picked.length >= maxProducts) break;
    final candidates = byCategory[cat]!
        .where((p) => !seenIds.contains(p.id))
        .toList();
    if (candidates.isEmpty) continue;

    candidates.sort((a, b) {
      final aNewStore = presentStores.contains(a.store.toLowerCase()) ? 0 : 1;
      final bNewStore = presentStores.contains(b.store.toLowerCase()) ? 0 : 1;
      if (aNewStore != bNewStore) return bNewStore.compareTo(aNewStore);
      return b.priority.compareTo(a.priority);
    });

    final chosen = candidates.first;
    picked.add(chosen);
    seenIds.add(chosen.id);
    presentStores.add(chosen.store.toLowerCase());
    categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
  }

  // Pass 2: fill remaining slots up to maxProducts, preferring missing stores first,
  // then least-represented categories, then highest priority.
  while (picked.length < maxProducts) {
    final remaining = eligible.where((p) => !seenIds.contains(p.id)).toList();
    if (remaining.isEmpty) break;

    remaining.sort((a, b) {
      final aNewStore = presentStores.contains(a.store.toLowerCase()) ? 0 : 1;
      final bNewStore = presentStores.contains(b.store.toLowerCase()) ? 0 : 1;
      if (aNewStore != bNewStore) return bNewStore.compareTo(aNewStore);

      final aCatCount = categoryCounts[a.category.toLowerCase()] ?? 0;
      final bCatCount = categoryCounts[b.category.toLowerCase()] ?? 0;
      if (aCatCount != bCatCount) return aCatCount.compareTo(bCatCount);

      return b.priority.compareTo(a.priority);
    });

    final chosen = remaining.first;
    picked.add(chosen);
    seenIds.add(chosen.id);
    presentStores.add(chosen.store.toLowerCase());
    final cat = chosen.category.toLowerCase();
    categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
  }

  return picked;
}

/// Places the top hero recommendation first (sunscreen when UV urgency is high,
/// otherwise highest priority), followed by remaining steps in skincare routine order.
List<AffiliateProduct> _orderForDisplay(
  List<AffiliateProduct> picked,
  SkinAnalysisRaw analysis,
) {
  if (picked.length <= 1) return picked;

  AffiliateProduct hero = picked.first;
  if (analysis.urgenciaProtetorSolar == 'alta') {
    final sunscreens = picked.where((p) => p.category == 'protetor').toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    if (sunscreens.isNotEmpty) {
      hero = sunscreens.first;
    } else {
      hero = picked.reduce((a, b) => a.priority >= b.priority ? a : b);
    }
  } else {
    hero = picked.reduce((a, b) => a.priority >= b.priority ? a : b);
  }

  final rest = picked.where((p) => p.id != hero.id).toList()
    ..sort((a, b) {
      final orderCmp = a.routineOrder.compareTo(b.routineOrder);
      if (orderCmp != 0) return orderCmp;
      return b.priority.compareTo(a.priority);
    });

  return [hero, ...rest];
}

bool _noteHits(AffiliateProduct product, String note, AppConfig config) {
  if (note.length < 3) return false;
  final brand = _fold(product.brand);
  if (brand.length >= 3 && note.contains(brand)) return true;
  final name = _fold(product.name);
  if (name.length >= 6 && note.contains(name)) return true;
  for (final id in product.ingredients) {
    final option = config.ingredients.where((i) => i.id == id);
    final words = <String>[
      id.replaceAll('_', ' '),
      if (option.isNotEmpty) option.first.label,
      if (option.isNotEmpty) ...option.first.keywords,
    ];
    for (final word in words) {
      final folded = _fold(word);
      if (folded.length >= 4 && note.contains(folded)) return true;
    }
  }
  return false;
}

String _fold(String value) {
  const from = 'áàâãäåéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaaeeeeiiiiooooouuuucn';
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}
