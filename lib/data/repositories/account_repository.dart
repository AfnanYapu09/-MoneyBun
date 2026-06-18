import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/enums/enums.dart';
import '../local/database.dart';

class AccountRepository {
  AccountRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<AccountRow>> watchAccounts() => _db.watchAccounts();

  Future<List<AccountRow>> getAccounts() => _db.getAccounts();

  Future<String> save({
    String? id,
    required String name,
    required AccountType type,
    String? bankCode,
    String? colorHex,
    String? iconKey,
    int openingBalanceCents = 0,
    int? sortOrder,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = id == null ? null : await _db.getAccount(id);
    final accId = id ?? _uuid.v4();
    final status = _nextStatus(existing?.syncStatus);

    await _db.upsertAccount(
      AccountsCompanion.insert(
        id: accId,
        name: name,
        type: type,
        bankCode: Value(bankCode),
        colorHex: Value(colorHex),
        iconKey: Value(iconKey),
        openingBalanceCents: Value(openingBalanceCents),
        sortOrder: Value(sortOrder ?? existing?.sortOrder ?? 0),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        remoteId: Value(existing?.remoteId),
        syncStatus: Value(status),
      ),
    );
    return accId;
  }

  /// Toggle whether MoneyBun auto-reads slips for this account.
  Future<void> setWatched(String id, bool watched) async {
    final existing = await _db.getAccount(id);
    if (existing == null) return;
    await _db.upsertAccount(
      existing
          .copyWith(
            watchedForSlips: watched,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            syncStatus: _nextStatus(existing.syncStatus),
          )
          .toCompanion(true),
    );
  }

  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _db.getAccount(id);
    if (existing == null) return;
    await _db.upsertAccount(
      AccountsCompanion.insert(
        id: id,
        name: existing.name,
        type: existing.type,
        createdAt: existing.createdAt,
        updatedAt: now,
        deleted: const Value(true),
        remoteId: Value(existing.remoteId),
        syncStatus: const Value(SyncStatus.pendingDelete),
      ),
    );
  }

  static SyncStatus _nextStatus(SyncStatus? current) {
    if (current == null || current == SyncStatus.pendingCreate) {
      return SyncStatus.pendingCreate;
    }
    return SyncStatus.pendingUpdate;
  }
}
