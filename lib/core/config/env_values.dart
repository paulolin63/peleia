// Resolve config from --dart-define / --dart-define-from-file=.env
// Never ship a real .env as a Flutter asset.
class EnvValues {
  EnvValues._();

  static String get peleiaEnv =>
      const String.fromEnvironment('PELEIA_ENV').trim();

  static String get geminiProxyUrl =>
      const String.fromEnvironment('GEMINI_PROXY_URL').trim();

  static String get geminiApiKey =>
      const String.fromEnvironment('GEMINI_API_KEY');

  static String get geminiModel {
    const fromDefine = String.fromEnvironment('GEMINI_MODEL');
    return fromDefine.isNotEmpty ? fromDefine : 'gemini-2.0-flash';
  }

  static String get revenueCatAndroidKey =>
      const String.fromEnvironment('REVENUECAT_ANDROID_KEY');

  static String normalizeProxyBase(String raw) {
    var url = raw.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/analyze')) {
      url = url.substring(0, url.length - '/analyze'.length);
    }
    if (url.endsWith('/config')) {
      url = url.substring(0, url.length - '/config'.length);
    }
    return url;
  }
}
