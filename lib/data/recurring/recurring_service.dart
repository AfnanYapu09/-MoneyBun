import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

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
      // Rules from before schema v9 carry no anchor; derive it from the next
      // occurrence (the best value still available) and persist it below so
      // the rule keeps a stable day from here on.
      final anchorDay =
          rule.anchorDay ?? DateTime.fromMillisecondsSinceEpoch(next).day;
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
        next = advance(next, rule.freq, anchorDay);
        guard++;
      }
      await _db.upsertRecurringRule(
        rule
            .copyWith(
              nextRunAt: next,
              anchorDay: Value(anchorDay),
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

  /// The occurrence after [ms] for [freq]. Monthly re-derives the day from
  /// [anchorDay] and clamps it to the target month's length, so a rule
  /// anchored on the 31st fires Jan 31 → Feb 28 → Mar 31. Without the clamp,
  /// Dart's DateTime normalisation turns "Feb 31" into Mar 3 — February is
  /// skipped and the rule silently re-anchors to the 3rd forever.
  @visibleForTesting
  static int advance(int ms, RecurFreq freq, int anchorDay) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final next = switch (freq) {
      RecurFreq.daily => d.add(const Duration(days: 1)),
      RecurFreq.weekly => d.add(const Duration(days: 7)),
      RecurFreq.monthly => _nextMonthly(d, anchorDay),
    };
    return next.millisecondsSinceEpoch;
  }

  static DateTime _nextMonthly(DateTime d, int anchorDay) {
    // Month overflow (13 → January next year) is safe to let DateTime
    // normalise; only the day-of-month must be clamped by hand.
    final firstOfNext = DateTime(d.year, d.month + 1);
    final lastDay = AppDate.daysInMonth(firstOfNext);
    return DateTime(
      firstOfNext.year,
      firstOfNext.month,
      anchorDay < lastDay ? anchorDay : lastDay,
      d.hour,
      d.minute,
    );
  }
}
