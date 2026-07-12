import '../../data/local/database.dart';
import '../widgets/pixel_icon.dart';

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
      if (en != null && en.isNotEmpty) return _presentableEn(en, iconKey);
    }
    return name;
  }
}

/// Rows saved while the icon catalogue still carried machine keys (e.g.
/// 'coffee_tea') — including rows synced down from older builds — hold that
/// key as their English name. Resolve those through the catalogue by glyph
/// id; failing that, prettify the key itself. Real display names (they carry
/// an uppercase letter or a space) pass through untouched.
String _presentableEn(String en, String iconKey) {
  final isMachineKey = !en.contains(' ') && en == en.toLowerCase();
  if (!isMachineKey) return en;
  final info = kPixelIconById[iconKey];
  if (info != null) return info.nameEn;
  final words = en.replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}
