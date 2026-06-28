/// Maps stored category `iconKey`s to modern emoji glyphs.
///
/// Categories store a stable string key (e.g. `food`, `transport`) so they stay
/// serialisable and DB/sync-driven — the key is unchanged from the original
/// seed data. This resolver turns that key into an emoji for display, replacing
/// the old Lucide line-icons with a friendlier, full-colour look. Keeping the
/// key (instead of storing the emoji) means existing data and Firestore docs
/// need no migration: only the rendering changes.
///
/// Accounts keep their Lucide icons via `CategoryIcons` — emoji are categories
/// only.
class CategoryEmoji {
  const CategoryEmoji._();

  /// Emoji by stored key. Covers every key used by the category seed
  /// (`SeedData`) and the new-category picker (`AddCategorySheet`), plus the
  /// extra lifestyle keys in `CategoryIcons` so any category resolves cleanly.
  static const Map<String, String> _byKey = {
    // Food & drink
    'food': '🍜',
    'coffee': '☕',
    'groceries': '🛒',
    // Shopping & lifestyle
    'shopping': '🛍️',
    'clothing': '👕',
    'beauty': '💇',
    'cosmetics': '💄',
    // Entertainment
    'entertainment': '🍿',
    'games': '🎮',
    'music': '🎵',
    'movie': '🎬',
    'book': '📚',
    'ticket': '🎫',
    // Transport
    'transport': '🚗',
    'car': '🚙',
    'fuel': '⛽',
    'bike': '🏍️',
    'travel': '✈️',
    // Home & bills
    'home': '🏠',
    'rent': '🔑',
    'electricity': '💡',
    'water': '💧',
    'gas': '🔥',
    'furniture': '🛋️',
    'utility': '🔌',
    'repair': '🔧',
    'phone_bill': '📱',
    'phone': '📞',
    'electronics': '💻',
    // Health
    'health': '🩺',
    'pharmacy': '💊',
    'clinic': '🏥',
    'health_fitness': '💪',
    // Family & pets
    'family': '👨‍👩‍👧‍👦',
    'baby': '👶',
    'dog': '🐶',
    'cat': '🐱',
    // People & giving
    'lend': '🤝',
    'gift': '🎁',
    'donate': '🙏',
    // Education & work
    'education': '🎓',
    'work': '💼',
    // Money & finance
    'insurance': '🛡️',
    'debt': '💳',
    'subscription': '🔁',
    'tax': '🧾',
    'money': '💵',
    'savings': '🐷',
    'invest': '📈',
    'sale': '🏷️',
    'coins': '🪙',
    'nature': '🌿',
    'package': '📦',
    // Income extras
    'salary': '💰',
    'bonus': '🎉',
    'refund': '↩️',
    // Fallback bucket ("อื่นๆ")
    'other': '🗂️',
  };

  /// The emoji for a stored [key]. Unknown keys fall back to "other" — except a
  /// key that is itself an emoji glyph (custom categories may store one), which
  /// is returned as-is so the picker can grow without a key per emoji.
  static String forKey(String? key) {
    if (key == null || key.isEmpty) return _byKey['other']!;
    final mapped = _byKey[key];
    if (mapped != null) return mapped;
    return _looksLikeEmoji(key) ? key : _byKey['other']!;
  }

  /// True when [s] starts in the Unicode symbol/emoji ranges (≥ U+2190), so a
  /// stored glyph passes through. ASCII keys and Thai text (≤ U+0E7F) do not.
  static bool _looksLikeEmoji(String s) => s.runes.first >= 0x2190;
}
