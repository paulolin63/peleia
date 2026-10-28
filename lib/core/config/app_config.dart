// Configuração pública do Peleia (sem prompts). Vem do asset, do cache ou do Worker.

class BenefitText {
  final String emoji;
  final String title;
  final String desc;
  const BenefitText({required this.emoji, required this.title, required this.desc});

  factory BenefitText.fromJson(Map<String, dynamic> json) => BenefitText(
        emoji: json['emoji'] as String? ?? '',
        title: json['title'] as String? ?? '',
        desc: json['desc'] as String? ?? '',
      );
}

class RoutineStepConfig {
  final String emoji;
  final String title;
  final String desc;
  final String safeDesc;
  final List<String> ingredients;
  const RoutineStepConfig({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.safeDesc,
    required this.ingredients,
  });

  factory RoutineStepConfig.fromJson(Map<String, dynamic> json) => RoutineStepConfig(
        emoji: json['emoji'] as String? ?? '',
        title: json['title'] as String? ?? '',
        desc: json['desc'] as String? ?? '',
        safeDesc: json['safe_desc'] as String? ?? '',
        ingredients: _strings(json['ingredients']),
      );

  String textFor(Set<String> avoided) {
    final blocked = ingredients.any(avoided.contains);
    if (blocked && safeDesc.isNotEmpty) return safeDesc;
    return desc;
  }
}

class IngredientOption {
  final String id;
  final String label;
  final List<String> keywords;
  const IngredientOption({required this.id, required this.label, required this.keywords});

  factory IngredientOption.fromJson(Map<String, dynamic> json) => IngredientOption(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        keywords: _strings(json['keywords']),
      );
}

class ConditionOption {
  final String id;
  final String label;
  final List<String> excludes;
  const ConditionOption({required this.id, required this.label, required this.excludes});

  factory ConditionOption.fromJson(Map<String, dynamic> json) => ConditionOption(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        excludes: _strings(json['excludes']),
      );
}

class PlanConfig {
  final String productId;
  final String label;
  final String badge;
  final String subtitle;
  final bool highlight;
  final bool consumable;
  const PlanConfig({
    required this.productId,
    required this.label,
    required this.badge,
    required this.subtitle,
    required this.highlight,
    required this.consumable,
  });

  factory PlanConfig.fromJson(Map<String, dynamic> json) => PlanConfig(
        productId: json['product_id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        badge: json['badge'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        highlight: json['highlight'] == true,
        consumable: json['consumable'] == true,
      );
}

class QuotaLimits {
  final int freeLifetime;
  final int proDaily;
  final int sosCredits;
  const QuotaLimits({required this.freeLifetime, required this.proDaily, required this.sosCredits});

  // Production default. Closed testing boosts free via PeleiaEnv / Worker ENVIRONMENT.
  static const fallback = QuotaLimits(freeLifetime: 1, proDaily: 2, sosCredits: 3);
}

class AppTexts {
  final String paywallTitle;
  final String paywallSubtitle;
  final List<BenefitText> paywallBenefits;
  final List<String> paywallSuccessItems;
  final String premiumBannerTitle;
  final String premiumBannerSubtitle;
  final String dailyLimitMessage;
  final String onboardingProductsSubtitle;
  final List<String> onboardingProductsBullets;
  final String dashboardSunTitle;
  final String dashboardSunBody;

  const AppTexts({
    required this.paywallTitle,
    required this.paywallSubtitle,
    required this.paywallBenefits,
    required this.paywallSuccessItems,
    required this.premiumBannerTitle,
    required this.premiumBannerSubtitle,
    required this.dailyLimitMessage,
    required this.onboardingProductsSubtitle,
    required this.onboardingProductsBullets,
    required this.dashboardSunTitle,
    required this.dashboardSunBody,
  });

  static const fallback = AppTexts(
    paywallTitle: 'Veja se a rotina\nestá funcionando',
    paywallSubtitle: 'Em 7 dias você compara oleosidade, acne e manchas. Cancele quando quiser.',
    paywallBenefits: [
      BenefitText(emoji: '📈', title: 'Evolução em 7 dias', desc: 'Compare selfies e veja se a rotina está dando resultado'),
      BenefitText(emoji: '🌅', title: 'Ritual manhã + noite', desc: 'Análise visual cosmética nos dois momentos do dia'),
      BenefitText(emoji: '🛍️', title: 'Pare de comprar errado', desc: 'Produtos sem os ingredientes que você pediu para evitar'),
    ],
    paywallSuccessItems: [
      '📈 Evolução da pele liberada',
      '🌅 Ritual manhã + noite ativado',
    ],
    premiumBannerTitle: 'Próximo passo: evolução',
    premiumBannerSubtitle: 'Volte em 7 dias e compare. Pro libera a próxima análise.',
    dailyLimitMessage: 'A pele precisa de tempo para responder à rotina. Volte amanhã para uma nova análise.',
    onboardingProductsSubtitle: 'Recomendamos marcas brasileiras e importadas\nnas principais lojas online.',
    onboardingProductsBullets: [
      '🛍️ Shopee, Mercado Livre e Amazon Brasil',
      '💚 Principia, Sallve, CeraVe, La Roche-Posay',
      '✅ Sem os ingredientes que você evitar',
    ],
    dashboardSunTitle: 'Proteção solar todos os dias',
    dashboardSunBody:
        'O índice UV no Brasil é alto o ano todo. Aplique protetor FPS 50+ pela manhã e reaplique a cada 2h se estiver ao sol ou suando.',
  );
}

class AppConfig {
  static const schemaVersion = 1;

  final int schema;
  final String version;
  final int minAppBuild;
  final String? notice;
  final QuotaLimits quota;
  final int maxProducts;
  final List<String> requiredCategories;
  final List<PlanConfig> plans;
  final AppTexts texts;
  final List<RoutineStepConfig> morning;
  final List<RoutineStepConfig> night;
  final List<IngredientOption> ingredients;
  final List<ConditionOption> conditions;
  final List<Map<String, dynamic>> products;

  const AppConfig({
    required this.schema,
    required this.version,
    required this.minAppBuild,
    required this.notice,
    required this.quota,
    required this.maxProducts,
    required this.requiredCategories,
    required this.plans,
    required this.texts,
    required this.morning,
    required this.night,
    required this.ingredients,
    required this.conditions,
    required this.products,
  });

  AppConfig copyWith({QuotaLimits? quota}) => AppConfig(
        schema: schema,
        version: version,
        minAppBuild: minAppBuild,
        notice: notice,
        quota: quota ?? this.quota,
        maxProducts: maxProducts,
        requiredCategories: requiredCategories,
        plans: plans,
        texts: texts,
        morning: morning,
        night: night,
        ingredients: ingredients,
        conditions: conditions,
        products: products,
      );

  /// Retorna null se o JSON não for do esquema suportado.
  static AppConfig? tryParse(Map<String, dynamic> json) {
    if (json['schema_version'] != schemaVersion) return null;
    final quota = json['quota'];
    final products = json['products'];
    if (quota is! Map || products is! List || products.isEmpty) return null;

    final rec = json['recommendation'] is Map ? json['recommendation'] as Map : const {};
    final texts = json['texts'] is Map ? json['texts'] as Map : const {};
    final routine = json['routine'] is Map ? json['routine'] as Map : const {};
    final profile = json['profile_options'] is Map ? json['profile_options'] as Map : const {};
    final notice = json['notice'];

    BenefitText benefit(dynamic item) =>
        item is Map ? BenefitText.fromJson(Map<String, dynamic>.from(item)) : const BenefitText(emoji: '', title: '', desc: '');

    final parsedBenefits = (texts['paywall_benefits'] as List?)?.map(benefit).where((b) => b.title.isNotEmpty).toList();
    final fallback = AppTexts.fallback;

    return AppConfig(
      schema: schemaVersion,
      version: json['config_version'] as String? ?? '',
      minAppBuild: _asInt(json['min_app_build'], 1),
      notice: notice is Map ? notice['message'] as String? : null,
      quota: QuotaLimits(
        freeLifetime: _asInt(quota['free_lifetime'], 1),
        proDaily: _asInt(quota['pro_daily'], 2),
        sosCredits: _asInt(quota['sos_credits'], 3),
      ),
      maxProducts: _asInt(rec['max_products'], 4),
      requiredCategories: _strings(rec['required_categories']),
      plans: [
        for (final item in (json['plans'] as List? ?? const []))
          if (item is Map) PlanConfig.fromJson(Map<String, dynamic>.from(item)),
      ],
      texts: AppTexts(
        paywallTitle: texts['paywall_title'] as String? ?? fallback.paywallTitle,
        paywallSubtitle: texts['paywall_subtitle'] as String? ?? fallback.paywallSubtitle,
        paywallBenefits: (parsedBenefits == null || parsedBenefits.isEmpty) ? fallback.paywallBenefits : parsedBenefits,
        paywallSuccessItems: _strings(texts['paywall_success_items']).isEmpty
            ? fallback.paywallSuccessItems
            : _strings(texts['paywall_success_items']),
        premiumBannerTitle: texts['premium_banner_title'] as String? ?? fallback.premiumBannerTitle,
        premiumBannerSubtitle: texts['premium_banner_subtitle'] as String? ?? fallback.premiumBannerSubtitle,
        dailyLimitMessage: texts['daily_limit_message'] as String? ?? fallback.dailyLimitMessage,
        onboardingProductsSubtitle:
            texts['onboarding_products_subtitle'] as String? ?? fallback.onboardingProductsSubtitle,
        onboardingProductsBullets: _strings(texts['onboarding_products_bullets']).isEmpty
            ? fallback.onboardingProductsBullets
            : _strings(texts['onboarding_products_bullets']),
        dashboardSunTitle: texts['dashboard_sun_title'] as String? ?? fallback.dashboardSunTitle,
        dashboardSunBody: texts['dashboard_sun_body'] as String? ?? fallback.dashboardSunBody,
      ),
      morning: [
        for (final item in (routine['morning'] as List? ?? const []))
          if (item is Map) RoutineStepConfig.fromJson(Map<String, dynamic>.from(item)),
      ],
      night: [
        for (final item in (routine['night'] as List? ?? const []))
          if (item is Map) RoutineStepConfig.fromJson(Map<String, dynamic>.from(item)),
      ],
      ingredients: [
        for (final item in (profile['ingredients'] as List? ?? const []))
          if (item is Map) IngredientOption.fromJson(Map<String, dynamic>.from(item)),
      ],
      conditions: [
        for (final item in (profile['conditions'] as List? ?? const []))
          if (item is Map) ConditionOption.fromJson(Map<String, dynamic>.from(item)),
      ],
      products: [
        for (final item in products)
          if (item is Map) Map<String, dynamic>.from(item),
      ],
    );
  }
}

List<String> _strings(dynamic value) =>
    value is List ? value.whereType<String>().toList() : const [];

int _asInt(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  return fallback;
}
