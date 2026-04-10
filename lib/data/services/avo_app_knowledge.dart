/// Static knowledge base about the Shoply app itself.
///
/// Avo's `get_app_info` tool looks up answers here instead of letting
/// Gemini hallucinate about features, pricing, or how things work.
/// Kept as plain Dart constants so prices, feature lists and copy are
/// source-of-truth and can't drift.
class AvoAppKnowledge {
  static const String appName = 'Shoply';
  static const String tagline =
      'Smart shopping lists with shared lists, AI categorization, recipes, and an AI assistant (that\'s me!).';

  // ── Pricing ──────────────────────────────────────────────────────

  static const String monthlyPrice = '\$2.99 / month';
  static const String yearlyPrice = '\$29.99 / year';
  static const String trial = '14-day free trial on both plans';
  static const String pricingSummary =
      '$monthlyPrice or $yearlyPrice. $trial — cancel anytime in Settings.';

  // ── Topics ───────────────────────────────────────────────────────
  //
  // Each key maps to a short, factual answer. Keys are matched
  // case-insensitively with partial matching so Gemini can ask for
  // "premium", "pricing", "how to share a list", etc.

  static const Map<String, String> topics = {
    // Premium & pricing
    'premium': 'Shoply Premium unlocks: unlimited shared lists, advanced AI '
        'categorization, unlimited AI chat with me, full recipe collection, '
        'nutrition info, custom themes, and priority sync. $pricingSummary',
    'pricing': pricingSummary,
    'cost': pricingSummary,
    'price': pricingSummary,
    'subscribe': 'You can subscribe in Profile → Premium. $pricingSummary',
    'trial': 'Every new premium subscription starts with a 14-day free trial. '
        'You won\'t be charged until the trial ends, and you can cancel any time.',
    'cancel': 'Subscriptions are managed by the App Store. Go to iOS Settings → '
        'your Apple ID → Subscriptions → Shoply to cancel.',

    // Core features
    'features': 'Shoply\'s main features: shared shopping lists with realtime '
        'sync, AI-powered ingredient categorization, a community recipe library, '
        'shopping history, home-screen widgets, Siri support, and me — Avo, your '
        'AI shopping assistant.',
    'shared lists': 'You can share any list: open the list, tap the share icon, '
        'and send the invite link. Members see items update in real time.',
    'share': 'To share a list: open it, tap the share button in the top bar, '
        'and send the invite link to anyone you shop with.',
    'recipes': 'The Recipes tab has a community recipe library. You can search, '
        'filter by dietary preferences, save favorites, and add every ingredient '
        'to a shopping list with one tap. Ask me to "find recipes" and I\'ll '
        'show them right here.',
    'widgets': 'Shoply has three iOS home-screen widget sizes. Long-press your '
        'home screen → + → search "Shoply" to add them. You can pick which list '
        'the widget shows.',
    'siri': 'You can say things like "Hey Siri, add milk to my Shoply list" — '
        'make sure Siri is enabled for Shoply in iOS Settings → Siri & Search.',
    'notifications': 'Push notifications tell you when someone edits a shared '
        'list. Toggle them in Profile → Settings → Notifications, or just ask '
        'me to turn them on or off.',
    'history': 'Every list you complete is saved to Shopping History so you can '
        'quickly re-add past items. I can show it to you — just ask.',
    'categories': 'Items are auto-sorted into categories (dairy, produce, etc.) '
        'using AI. The category ID is language-agnostic, so a list shared '
        'between a German and English user shows each person the category in '
        'their own language.',
    'languages': 'Shoply is available in English and German. You can switch '
        'in Profile → Settings → Language, or ask me to change it.',
    'diet': 'You can set dietary preferences (vegan, vegetarian, keto, etc.) '
        'and allergies in Profile → Settings → Dietary Preferences. Recipes '
        'and suggestions respect these automatically.',
    'allergies': 'Set your allergies in Profile → Settings → Dietary Preferences. '
        'I\'ll avoid recipes with matching ingredients when you ask me to find '
        'something to cook.',
    'offline': 'Shoply works offline for viewing and editing. Changes sync '
        'automatically when you\'re back online.',
    'avo': 'I\'m Avo, your shopping assistant. I can search recipes, add items '
        'to your lists, show your shopping history, check off items, change '
        'your settings, estimate recipe calories, and answer any question '
        'about the app. Just ask!',
    'privacy': 'Your lists and data are stored in Supabase with row-level '
        'security — only you and people you explicitly share with can see them.',
  };

  /// Look up an answer for a topic, doing case-insensitive partial matching.
  /// Returns the best match or null.
  static String? lookup(String topic) {
    final q = topic.toLowerCase().trim();
    if (q.isEmpty) return null;

    // Exact match first.
    if (topics.containsKey(q)) return topics[q];

    // Partial match — return the first key contained in the query or vice versa.
    for (final entry in topics.entries) {
      if (q.contains(entry.key) || entry.key.contains(q)) {
        return entry.value;
      }
    }
    return null;
  }

  /// A short summary of every topic Avo can answer about the app.
  /// Used in the system prompt so Gemini knows what it can ask for.
  static String get topicsSummary => topics.keys.join(', ');
}
