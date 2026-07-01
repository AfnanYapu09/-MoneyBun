import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/app_date.dart';
import '../../domain/enums/enums.dart';
import '../local/database.dart';

/// Transactions. Each row is an income / expense / transfer. Slip imports use
/// the defaults ([TxnType.expense], empty account) so the slip pipeline stays
/// unchanged; the Add sheet passes the full shape.
class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<TransactionRow>> watchMonth(DateTime month) {
    final start = AppDate.toMillis(AppDate.startOfMonth(month));
    final end = AppDate.toMillis(AppDate.endOfMonth(month));
    return _db.watchTransactionsBetween(start, end);
  }

  /// Active transactions whose `occurredAt` falls in `[startMs, endMs]`.
  Stream<List<TransactionRow>> watchBetween(int startMs, int endMs) =>
      _db.watchTransactionsBetween(startMs, endMs);

  Stream<List<TransactionRow>> watchAll() => _db.watchActiveTransactions();

  Future<TransactionRow?> get(String id) => _db.getTransaction(id);

  Future<List<String>> tagIds(String id) => _db.tagIdsForTransaction(id);

  /// Create or update a transaction. When [tagIds] is non-null the tag set is
  /// replaced; pass null to leave existing links untouched.
  Future<String> save({
    String? id,
    TxnType type = TxnType.expense,
    required int amountCents,
    String currency = 'THB',
    String? accountId,
    String? toAccountId,
    String? categoryId,
    String? note,
    required DateTime occurredAt,
    String? slipId,
    List<String>? tagIds,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = id == null ? null : await _db.getTransaction(id);
    final txnId = id ?? _uuid.v4();

    await _db.upsertTransaction(
      TransactionsCompanion.insert(
        id: txnId,
        type: type,
        amountCents: amountCents,
        currency: Value(currency),
        accountId: accountId ?? existing?.accountId ?? '',
        // Written straight through (not null-coalesced) so switching an entry
        // away from a transfer can clear its destination account.
        toAccountId: Value(toAccountId),
        categoryId: Value(categoryId),
        note: Value(note),
        occurredAt: AppDate.toMillis(occurredAt),
        slipId: Value(slipId ?? existing?.slipId),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        remoteId: Value(existing?.remoteId),
        syncStatus: Value(_nextStatus(existing?.syncStatus)),
      ),
    );
    if (tagIds != null) {
      await _db.setTransactionTags(txnId, tagIds);
    }
    return txnId;
  }

  /// Reclassify a slip-imported expense as a transfer. Used when a slip shows
  /// money moving between the user's own accounts (sender name == receiver
  /// name); transfers are excluded from every spending statistic. Idempotent.
  Future<void> reclassifyAsTransfer(String id) async {
    final existing = await _db.getTransaction(id);
    if (existing == null || existing.type == TxnType.transfer) return;
    await _db.upsertTransaction(
      existing
          .copyWith(
            type: TxnType.transfer,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            syncStatus: _nextStatus(existing.syncStatus),
          )
          .toCompanion(true),
    );
  }

  /// Assign/clear the category of an entry (the home-screen tap action).
  Future<void> setCategory(String id, String? categoryId) async {
    final existing = await _db.getTransaction(id);
    if (existing == null) return;
    await _db.upsertTransaction(
      existing
          .copyWith(
            categoryId: Value(categoryId),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            syncStatus: _nextStatus(existing.syncStatus),
          )
          .toCompanion(true),
    );
  }

  Future<void> delete(String id) =>
      _db.softDeleteTransaction(id, DateTime.now().millisecondsSinceEpoch);

  static SyncStatus _nextStatus(SyncStatus? current) {
    if (current == null || current == SyncStatus.pendingCreate) {
      return SyncStatus.pendingCreate;
    }
    return SyncStatus.pendingUpdate;
  }
}
