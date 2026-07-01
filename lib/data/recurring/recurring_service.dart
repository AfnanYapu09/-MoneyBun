import 'package:drift/drift.dart';

import '../../core/utils/app_date.dart';
import '../../domain/enums/enums.dart';
import '../local/database.dart';
import '../repositories/transaction_repository.dart';

/// Turns recurring rules into real transactions.
///
/// [runDue] is called once per app launch. For every active rule whose
/// `nextRunAt` is due it creates the transaction(s) that should have fired
/// (catching up any missed periods, capped), then advances the rule's
/// `nextRunAt` to the first occurrence still in the future.
class RecurringService {
  RecurringService(this._db, this._txns);

  final AppDatabase _db;
  final TransactionRepository _txns;

  /// Safety cap so a mis-dated rule can never spin creating unbounded rows.
  static const _maxCatchUp = 400;

  /// Returns how many transactions were created.
  Future<int> runDue() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var created = 0;
    for (final rule in await _db.dueRecurringRules(now)) {
      var next = rule.nextRunAt;
      var guard = 0;
      while (next <= now && guard < _maxCatchUp) {
        // Deterministic id (rule + occurrence) so the same occurrence generated
        // on two devices collides on the primary key and merges instead of
        // duplicating. Skip if a row with that id already exists — including a
        // soft-deleted tombstone — so re-running never duplicates and never
        // resurrects an occurrence the user deleted.
        final occurrenceId = '${rule.id}_$next';
        if (await _db.getTransaction(occurrenceId) == null) {
          await _txns.save(
            id: occurrenceId,
            type: rule.type,
            amountCents: rule.amountCents,
            categoryId: rule.categoryId,
            note: rule.note,
            occurredAt: AppDate.fromMillis(next),
          );
          created++;
        }
        next = _advance(next, rule.freq);
        guard++;
      }
      await _db.upsertRecurringRule(
        rule
            .copyWith(
              nextRunAt: next,
              lastRunAt: Value(now),
              updatedAt: now,
              syncStatus: rule.syncStatus == SyncStatus.pendingCreate
                  ? SyncStatus.pendingCreate
                  : SyncStatus.pendingUpdate,
            )
            .toCompanion(true),
      );
    }
    return created;
  }

  int _advance(int ms, RecurFreq freq) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final next = switch (freq) {
      RecurFreq.daily => d.add(const Duration(days: 1)),
      RecurFreq.weekly => d.add(const Duration(days: 7)),
      RecurFreq.monthly =>
        DateTime(d.year, d.month + 1, d.day, d.hour, d.minute),
    };
    return next.millisecondsSinceEpoch;
  }
}
