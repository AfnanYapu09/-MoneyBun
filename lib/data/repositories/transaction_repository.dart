import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/app_date.dart';
import '../../domain/enums/enums.dart';
import '../local/database.dart';

/// Writes/reads transactions through the local Drift database, stamping sync
/// bookkeeping so the SyncEngine can later push changes to Firestore.
class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Stream<List<TransactionRow>> watchMonth(DateTime month) {
    final start = AppDate.toMillis(AppDate.startOfMonth(month));
    final end = AppDate.toMillis(AppDate.endOfMonth(month));
    return _db.watchTransactionsBetween(start, end);
  }

  Stream<List<TransactionRow>> watchAll() => _db.watchActiveTransactions();

  Future<TransactionRow?> get(String id) => _db.getTransaction(id);

  /// Create or update a transaction. When [id] refers to an existing row, the
  /// edit is marked `pendingUpdate` (unless it was still `pendingCreate`).
  Future<String> save({
    String? id,
    required TxnType type,
    required int amountCents,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    String? note,
    required DateTime occurredAt,
    String? slipId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = id == null ? null : await _db.getTransaction(id);
    final txnId = id ?? _uuid.v4();
    final status = _nextStatus(existing?.syncStatus);

    await _db.upsertTransaction(
      TransactionsCompanion.insert(
        id: txnId,
        type: type,
        amountCents: amountCents,
        accountId: accountId,
        toAccountId: Value(toAccountId),
        categoryId: Value(type == TxnType.transfer ? null : categoryId),
        note: Value(note),
        occurredAt: AppDate.toMillis(occurredAt),
        slipId: Value(slipId),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        remoteId: Value(existing?.remoteId),
        syncStatus: Value(status),
      ),
    );
    return txnId;
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
