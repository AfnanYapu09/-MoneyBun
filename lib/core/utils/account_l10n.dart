import '../../data/local/database.dart';
import '../constants/account_seed.dart';

/// Locale-aware display name for an account.
///
/// The Accounts table stores a single [AccountRow.name] (Thai for the default
/// seeded wallets/banks). The seeds carry an English name keyed by their stable
/// `sys_acc_*` id, so for English we resolve the seed's `nameEn`; user-created
/// accounts (non-seed ids) only have [name] and are shown as-is in either
/// language.
extension AccountDisplayName on AccountRow {
  String displayName(String locale) {
    if (locale.startsWith('en')) {
      for (final s in AccountSeedData.accounts) {
        if (s.id == id) return s.nameEn;
      }
    }
    return name;
  }
}
