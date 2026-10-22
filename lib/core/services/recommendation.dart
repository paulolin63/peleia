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
        analysis.problemasDetectados.any((prob) => prob.contains(type) || type.contains(prob)));
  }

  final matching = all.where(relevant).toList()
    ..sort((a, b) => b.priority.compareTo(a.priority));

  final hidden = matching.where(excluded).length;
  final picked = matching.where((p) => !excluded(p)).take(config.maxProducts).toList();

  var missingSunscreen = false;
  for (final category in config.requiredCategories) {
    final has = picked.any((p) => p.category == category);
    if (has) continue;
    final candidates = all.where((p) => p.category == category && !excluded(p)).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    if (candidates.isEmpty) {
      if (category == 'protetor') missingSunscreen = true;
      continue;
    }
    if (picked.length >= config.maxProducts) picked.removeLast();
    picked.add(candidates.first);
  }

  return ProductRecommendation(
    products: picked,
    hiddenCount: hidden,
    missingSunscreen: missingSunscreen,
    avoidedLabels: labels,
  );
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
