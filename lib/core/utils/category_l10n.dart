import '../../data/local/database.dart';

/// Locale-aware display name for a category.
///
/// System categories carry an English name (`nameEn`) alongside their Thai
/// [CategoryRow.name]; user-created categories only have [CategoryRow.name],
/// which is shown in either language. This keeps the rest of the UI free of
/// the `locale == 'en' ? … : …` branching.
extension CategoryDisplayName on CategoryRow {
  String displayName(String locale) {
    if (locale.startsWith('en')) {
      final en = nameEn;
      if (en != null && en.isNotEmpty) return en;
    }
    return name;
  }
}
