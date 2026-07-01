import '../local/database.dart';

/// Read-only access to the user's accounts/wallets.
///
/// Accounts are seeded once on first run (see `account_seed.dart`) and are not
/// user-editable, so this repository only exposes reads. The banks scanned for
/// slips are chosen separately via `settings.disabledScanIds` (accounts sheet).
class AccountRepository {
  AccountRepository(this._db);

  final AppDatabase _db;

  Stream<List<AccountRow>> watchAccounts() => _db.watchAccounts();

  Future<List<AccountRow>> getAccounts() => _db.getAccounts();
}
