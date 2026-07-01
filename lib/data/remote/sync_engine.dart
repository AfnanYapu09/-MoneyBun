import 'package:cloud_firestore/cloud_firestore.dart';

import '../local/database.dart';
import 'auth_service.dart';
import 'firestore_mappers.dart';

/// Local-first sync. Drift is the source of truth. On [sync] we pull the
/// signed-in user's Firestore collections into the local DB first — so a fresh
/// login on a new device paints the user's real data as fast as possible — then
/// push any locally-changed rows back up. Conflicts resolve last-write-wins by
/// `updatedAt`, so pulling first never loses a pending local edit (those carry a
/// newer `updatedAt` and win the comparison; they're uploaded on the push pass).
///
/// Deletes are pushed as soft-delete tombstones (`deleted: true`), not as
/// document removals, so other devices learn about a deletion on their next
/// pull. Document id == row id.
///
/// Pull is incremental: each collection keeps a high-water mark (the max
/// `updatedAt` already pulled) and fetches only `updatedAt` greater than that,
/// minus a [_pullMargin] safety window so a device whose clock lags (up to the
/// margin) isn't skipped. The watermark is clamped to this device's own `now`
/// when advanced, so a device whose clock runs *fast* can't jump the cursor into
/// the future and hide other devices' edits. The first pull (watermark 0)
/// fetches everything. Tombstones bump `updatedAt`, so deletes still arrive
/// through the cursor. (A monotonic server timestamp would remove the residual
/// dependence on client clocks entirely — a planned follow-up.)
///
/// [pushOnly] uploads pending local changes without pulling — used by the
/// automatic on-change sync so frequent edits don't run up Firestore reads.
class SyncEngine {
  SyncEngine(this._db, this._fs, this._auth);

  final AppDatabase _db;
  final FirebaseFirestore _fs;
  final AuthService _auth;

  bool _running = false;

  /// Hard bound on a sync's network work so a stalled Firestore call (flaky
  /// network, captive portal) can't leave [_running] stuck true and silently
  /// block every future sync. On timeout the run is abandoned and rows stay
  /// pending for the next trigger.
  static const _networkTimeout = Duration(seconds: 30);

  /// Re-read window subtracted from each collection's pull watermark. An
  /// incremental pull fetches `updatedAt > watermark - _pullMargin`, so a doc
  /// stamped up to this far behind the newest one (e.g. a device whose clock
  /// lags) is still picked up instead of being skipped by the cursor.
  static const _pullMargin = Duration(days: 7);

  /// Age past which a synced soft-delete tombstone is garbage-collected locally.
  /// Comfortably beyond [_pullMargin] so a collected tombstone isn't re-fetched.
  static const _tombstoneRetention = Duration(days: 90);

  CollectionReference<Map<String, dynamic>> _col(String uid, String name) =>
      _fs.collection('users').doc(uid).collection(name);

  /// Full sync (pull + push). Returns true if it completed (user signed in and
  /// no error/timeout); best-effort, never throws.
  ///
  /// Pull runs before push so the user's cloud data reaches the local DB — and
  /// the home screen — without waiting for the initial upload of freshly-seeded
  /// defaults. On a first login the seeds carry `updatedAt: 0`, so the real
  /// cloud rows win the last-write-wins comparison and overwrite them instead of
  /// the defaults being pushed back over the user's data.
  Future<bool> sync() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _running) return false;
    _running = true;
    try {
      await _pullAll(uid).timeout(_networkTimeout);
      await _pushAll(uid).timeout(_networkTimeout);
      // Reclaim old tombstones after a successful sync (best-effort, local-only
      // — never fail the sync over housekeeping).
      try {
        await _db.gcTombstones(
          DateTime.now().millisecondsSinceEpoch -
              _tombstoneRetention.inMilliseconds,
        );
      } catch (_) {}
      return true;
    } catch (_) {
      // Best-effort: a failed/timed-out sync is retried on the next trigger.
      return false;
    } finally {
      _running = false;
    }
  }

  /// Push pending local changes only (no pull). Cheap — no reads. Best-effort,
  /// never throws.
  Future<bool> pushOnly() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _running) return false;
    _running = true;
    try {
      await _pushAll(uid).timeout(_networkTimeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      _running = false;
    }
  }

  // Run the collections concurrently — each is an independent network call, so
  // the whole sync takes about as long as the slowest one instead of the sum.
  Future<void> _pushAll(String uid) => Future.wait([
        _pushTransactions(uid),
        _pushAccounts(uid),
        _pushCategories(uid),
        _pushSlips(uid),
        _pushBudgets(uid),
        _pushTags(uid),
        _pushRecurringRules(uid),
      ]);

  Future<void> _pullAll(String uid) => Future.wait([
        _pullAccounts(uid),
        _pullCategories(uid),
        _pullTags(uid),
        _pullTransactions(uid),
        _pullBudgets(uid),
        _pullSlips(uid),
        _pullRecurringRules(uid),
      ]);

  // ---- Push (a soft-deleted row carries deleted:true in its map) ----------

  /// Upload [map] to [doc] only when our copy is at least as new as the cloud's,
  /// so an older local row — an untouched seed (updatedAt 0) or a stale offline
  /// edit — can never clobber newer cloud data. This mirrors the pull's
  /// last-write-wins rule on the push side, which a bare `.set()` would skip. If
  /// the cloud copy is newer the write is skipped; the caller still marks the row
  /// synced and the next pull brings the newer value down to reconcile locally.
  Future<void> _pushDoc(
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, dynamic> map,
  ) async {
    final localUpdated = (map['updatedAt'] as num?)?.toInt() ?? 0;
    await _fs.runTransaction((txn) async {
      final snap = await txn.get(doc);
      final remoteUpdated = (snap.data()?['updatedAt'] as num?)?.toInt();
      if (remoteUpdated == null || localUpdated >= remoteUpdated) {
        txn.set(doc, map);
      }
    });
  }

  // Rows within a collection upload concurrently (each is an independent
  // last-write-wins transaction on a distinct doc), so the first sync of a
  // freshly-seeded device isn't a long chain of serial round-trips.

  Future<void> _pushTransactions(String uid) async {
    final pending = await _db.pendingTransactions();
    if (pending.isEmpty) return;
    final col = _col(uid, 'transactions');
    // Fetch every tag link once instead of one query per pending row.
    final tagsByTxn = <String, List<String>>{};
    for (final link in await _db.getAllTransactionTags()) {
      (tagsByTxn[link.transactionId] ??= []).add(link.tagId);
    }
    await Future.wait(pending.map((r) async {
      final map = FirestoreMappers.transactionToMap(r);
      // Embed the tag links so they sync without a separate collection.
      map['tagIds'] = tagsByTxn[r.id] ?? const <String>[];
      await _pushDoc(col.doc(r.id), map);
      await _db.markTransactionSynced(r.id);
    }));
  }

  Future<void> _pushAccounts(String uid) async {
    final col = _col(uid, 'accounts');
    await Future.wait((await _db.pendingAccounts()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.accountToMap(r));
      await _db.markAccountSynced(r.id);
    }));
  }

  Future<void> _pushCategories(String uid) async {
    final col = _col(uid, 'categories');
    await Future.wait((await _db.pendingCategories()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.categoryToMap(r));
      await _db.markCategorySynced(r.id);
    }));
  }

  Future<void> _pushSlips(String uid) async {
    final col = _col(uid, 'slips');
    await Future.wait((await _db.pendingSlips()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.slipToMap(r));
      await _db.markSlipSynced(r.id);
    }));
  }

  Future<void> _pushBudgets(String uid) async {
    final col = _col(uid, 'budgets');
    await Future.wait((await _db.pendingBudgets()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.budgetToMap(r));
      await _db.markBudgetSynced(r.id);
    }));
  }

  Future<void> _pushTags(String uid) async {
    final col = _col(uid, 'tags');
    await Future.wait((await _db.pendingTags()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.tagToMap(r));
      await _db.markTagSynced(r.id);
    }));
  }

  Future<void> _pushRecurringRules(String uid) async {
    final col = _col(uid, 'recurringRules');
    await Future.wait((await _db.pendingRecurringRules()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.recurringRuleToMap(r));
      await _db.markRecurringRuleSynced(r.id);
    }));
  }

  // ---- Pull (incremental, last-write-wins; deleted:true rows soft-delete) ---

  /// Fetch only docs changed since this collection's watermark (minus the
  /// clock-skew [_pullMargin]). A watermark of 0 fetches everything.
  Future<QuerySnapshot<Map<String, dynamic>>> _incrementalPull(
    String uid,
    String name,
  ) async {
    final watermark = await _db.pullWatermark(name);
    final since = watermark - _pullMargin.inMilliseconds;
    return _col(uid, name).where('updatedAt', isGreaterThan: since).get();
  }

  /// Advance a collection's watermark, clamped to this device's own `now` so a
  /// future-dated remote timestamp (a peer with a fast clock) can't push the
  /// cursor past real time and start hiding other devices' edits.
  Future<void> _saveWatermark(String name, int maxUpdated) {
    if (maxUpdated <= 0) return Future<void>.value();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return _db.setPullWatermark(name, maxUpdated < nowMs ? maxUpdated : nowMs);
  }

  /// Whether a fetched doc is a tombstone for a row we don't hold locally — such
  /// a doc has nothing to soft-delete, so storing it would only get it
  /// re-collected by [AppDatabase.gcTombstones] and re-fetched next sync.
  bool _isAbsentTombstone(Map<String, dynamic> data, int? localUpdatedAt) =>
      localUpdatedAt == null && data['deleted'] == true;

  Future<void> _pullAccounts(String uid) async {
    final snap = await _incrementalPull(uid, 'accounts');
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.accountsUpdatedAt();
    final rows = <AccountsCompanion>[];
    var maxUpdated = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteUpdated > maxUpdated) maxUpdated = remoteUpdated;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.accountFromMap(doc.id, data));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertAccounts(rows);
    await _saveWatermark('accounts', maxUpdated);
  }

  Future<void> _pullCategories(String uid) async {
    final snap = await _incrementalPull(uid, 'categories');
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.categoriesUpdatedAt();
    final rows = <CategoriesCompanion>[];
    var maxUpdated = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteUpdated > maxUpdated) maxUpdated = remoteUpdated;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.categoryFromMap(doc.id, data));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertCategories(rows);
    await _saveWatermark('categories', maxUpdated);
  }

  Future<void> _pullTags(String uid) async {
    final snap = await _incrementalPull(uid, 'tags');
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.tagsUpdatedAt();
    final rows = <TagsCompanion>[];
    var maxUpdated = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteUpdated > maxUpdated) maxUpdated = remoteUpdated;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.tagFromMap(doc.id, data));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertTags(rows);
    await _saveWatermark('tags', maxUpdated);
  }

  Future<void> _pullTransactions(String uid) async {
    final snap = await _incrementalPull(uid, 'transactions');
    if (snap.docs.isEmpty) return;
    // One query for all local updatedAt instead of a read per row.
    final localUpdated = await _db.transactionsUpdatedAt();
    final rows = <TransactionsCompanion>[];
    final tagWrites = <MapEntry<String, List<String>>>[];
    var maxUpdated = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteUpdated > maxUpdated) maxUpdated = remoteUpdated;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.transactionFromMap(doc.id, data));
        final tagIds =
            (data['tagIds'] as List?)?.whereType<String>().toList() ??
                const <String>[];
        // New rows have no links to clear, so only write links when there are
        // tags or the row already existed (so tag removals still propagate).
        if (tagIds.isNotEmpty || localUpdatedAt != null) {
          tagWrites.add(MapEntry(doc.id, tagIds));
        }
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertTransactions(rows);
    for (final w in tagWrites) {
      await _db.setTransactionTags(w.key, w.value);
    }
    await _saveWatermark('transactions', maxUpdated);
  }

  Future<void> _pullBudgets(String uid) async {
    final snap = await _incrementalPull(uid, 'budgets');
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.budgetsUpdatedAt();
    final rows = <BudgetsCompanion>[];
    var maxUpdated = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteUpdated > maxUpdated) maxUpdated = remoteUpdated;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.budgetFromMap(doc.id, data));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertBudgets(rows);
    await _saveWatermark('budgets', maxUpdated);
  }

  Future<void> _pullSlips(String uid) async {
    final snap = await _incrementalPull(uid, 'slips');
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.slipsUpdatedAt();
    final rows = <SlipsCompanion>[];
    var maxUpdated = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteUpdated > maxUpdated) maxUpdated = remoteUpdated;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.slipFromMap(doc.id, data));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertSlips(rows);
    await _saveWatermark('slips', maxUpdated);
  }

  Future<void> _pullRecurringRules(String uid) async {
    final snap = await _incrementalPull(uid, 'recurringRules');
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.recurringRulesUpdatedAt();
    final rows = <RecurringRulesCompanion>[];
    var maxUpdated = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteUpdated > maxUpdated) maxUpdated = remoteUpdated;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.recurringRuleFromMap(doc.id, data));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertRecurringRules(rows);
    await _saveWatermark('recurringRules', maxUpdated);
  }
}
