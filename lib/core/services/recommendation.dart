import '../../features/scan/data/skin_analysis_result.dart';
import '../config/app_config.dart';
import '../profile/user_profile.dart';

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

ProductRecommendation recommendProducts({
  required AppConfig config,
  required SkinAnalysisRaw analysis,
  required UserProfile profile,
  List<AffiliateProduct>? catalog,
}) {
  final avoided = profile.avoidedIds(config);
  final labels = profile.avoidedLabels(config);
  final note = _fold(profile.note);

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
  final eligible = matching.where((p) => !excluded(p)).toList();

  // Prefer covering Shopee + Mercado Livre + Amazon before stacking one store.
  final picked = _pickStoreDiverse(eligible, config.maxProducts);

  var missingSunscreen = false;
  for (final category in config.requiredCategories) {
    final has = picked.any((p) => p.category == category);
    if (has) continue;
    final candidates = all
        .where((p) => p.category == category && !excluded(p))
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    if (candidates.isEmpty) {
      if (category == 'protetor') missingSunscreen = true;
      continue;
    }
    // Prefer a candidate whose store is missing from the current pick.
    final presentStores = picked.map((p) => p.store).toSet();
    candidates.sort((a, b) {
      final aNew = presentStores.contains(a.store) ? 0 : 1;
      final bNew = presentStores.contains(b.store) ? 0 : 1;
      if (aNew != bNew) return bNew.compareTo(aNew);
      return b.priority.compareTo(a.priority);
    });
    if (picked.length >= config.maxProducts) {
      // Drop a duplicate-store item first if possible.
      final dupIdx = picked.lastIndexWhere(
        (p) => picked.where((x) => x.store == p.store).length > 1,
      );
      picked.removeAt(dupIdx >= 0 ? dupIdx : picked.length - 1);
    }
    picked.add(candidates.first);
  }

  return ProductRecommendation(
    products: picked,
    hiddenCount: hidden,
    missingSunscreen: missingSunscreen,
    avoidedLabels: labels,
  );
}

/// Round-robin across marketplaces so the list always surfaces multiple stores.
List<AffiliateProduct> _pickStoreDiverse(
  List<AffiliateProduct> eligible,
  int maxProducts,
) {
  if (eligible.isEmpty || maxProducts <= 0) return [];

  final queues = <String, List<AffiliateProduct>>{
    for (final store in kAffiliateStores) store: <AffiliateProduct>[],
  };
  final other = <AffiliateProduct>[];

  for (final product in eligible) {
    final key = product.store.toLowerCase();
    if (queues.containsKey(key)) {
      queues[key]!.add(product);
    } else {
      other.add(product);
    }
  }

  final picked = <AffiliateProduct>[];
  final seen = <String>{};

  // Pass 1: one best product per known store.
  for (final store in kAffiliateStores) {
    if (picked.length >= maxProducts) break;
    final queue = queues[store]!;
    if (queue.isEmpty) continue;
    final next = queue.removeAt(0);
    if (seen.add(next.id)) picked.add(next);
  }

  // Pass 2: round-robin fill remaining slots.
  var progressed = true;
  while (picked.length < maxProducts && progressed) {
    progressed = false;
    for (final store in kAffiliateStores) {
      if (picked.length >= maxProducts) break;
      final queue = queues[store]!;
      if (queue.isEmpty) continue;
      final next = queue.removeAt(0);
      if (seen.add(next.id)) {
        picked.add(next);
        progressed = true;
      }
    }
  }

  for (final product in other) {
    if (picked.length >= maxProducts) break;
    if (seen.add(product.id)) picked.add(product);
  }

  return picked;
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
