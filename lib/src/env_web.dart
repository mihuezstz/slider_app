import 'dart:js' as js;

/// Implementación para web: lee window.env (config.js)
Map<String, String>? getWebEnv() {
  try {
    final ctx = js.context;
    final url = ctx['env']?['SUPABASE_URL'];
    final anon = ctx['env']?['SUPABASE_ANON'];
    if (url == null || anon == null) return null;
    return {
      'SUPABASE_URL': url as String,
      'SUPABASE_ANON': anon as String,
    };
  } catch (_) {
    return null;
  }
}