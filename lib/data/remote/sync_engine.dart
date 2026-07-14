import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../local/database.dart';
import '../session_guard.dart';
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
/// `pushedAt` already pulled — when a doc REACHED the cloud, stamped by
/// [_pushDoc], as opposed to `updatedAt`, when it was edited) and fetches only
/// `pushedAt` greater than that, minus a [_pullMargin] safety window so a
/// device whose clock lags (up to the margin) isn't skipped. Cursoring on
/// pushedAt means a doc uploaded long after it was edited (a device offline
/// for weeks) still lands inside every peer's window; conflicts still resolve
/// on `updatedAt`. The watermark is clamped to this device's own `now` when
/// advanced, so a device whose clock runs *fast* can't jump the cursor into
/// the future and hide other devices' edits. The first pull (watermark 0)
/// fetches everything. Tombstones bump `updatedAt` and re-push, so deletes
/// still arrive through the cursor. (A monotonic server timestamp would remove
/// the residual dependence on client clocks entirely — a planned follow-up.)
///
/// [pushOnly] uploads pending local changes without pulling — used by the
/// automatic on-change sync so frequent edits don't run up Firestore reads.
class SyncEngine {
  SyncEngine(this._db, this._fs, this._auth, this._gen);

  final AppDatabase _db;
  final FirebaseFirestore _fs;
  final AuthService _auth;
  final SessionGeneration _gen;

  bool _running = false;

  /// Hard bound on a sync's network work so a stalled Firestore call (flaky
  /// network, captive portal) can't leave [_running] stuck true and silently
  /// block every future sync. On timeout the run is abandoned and rows stay
  /// pending for the next trigger.
  static const _networkTimeout = Duration(seconds: 30);

  /// Re-read window subtracted from each collection's pull watermark. An
  /// incremental pull fetches `pushedAt > watermark - _pullMargin`, so a doc
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
    // Claim the single-flight guard BEFORE the first await: two near-
    // simultaneous callers (e.g. SyncController's constructor microtask and
    // its auth-state replay both firing at launch) must not both observe
    // `_running == false` and run concurrently. _ownsLocalDb is an async DB
    // read — awaiting it before claiming _running would reopen exactly that
    // race, so the ownership check happens AFTER the claim and releases the
    // guard on failure instead.
    _running = true;
    if (!await _ownsLocalDb(uid)) {
      _running = false;
      return false;
    }
    final gen = _gen.value;
    try {
      await _pullAll(uid, gen).timeout(_networkTimeout);
      await _pushAll(uid, gen).timeout(_networkTimeout);
      // Reclaim old tombstones after a successful sync (best-effort, local-only
      // — never fail the sync over housekeeping).
      try {
        await _db.gcTombstones(
          DateTime.now().millisecondsSinceEpoch -
              _tombstoneRetention.inMilliseconds,
        );
      } catch (_) {}
      return true;
    } catch (e) {
      // Best-effort: a failed/timed-out sync is retried on the next trigger.
      // Logged (not rethrown) so a systemic failure — e.g. PERMISSION_DENIED
      // from undeployed Firestore rules — is visible instead of silent.
      debugPrint('SyncEngine.sync failed: $e');
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
    // Same atomic-claim-before-await reasoning as sync() above.
    _running = true;
    if (!await _ownsLocalDb(uid)) {
      _running = false;
      return false;
    }
    final gen = _gen.value;
    try {
      await _pushAll(uid, gen).timeout(_networkTimeout);
      return true;
    } catch (e) {
      debugPrint('SyncEngine.pushOnly failed: $e');
      return false;
    } finally {
      _running = false;
    }
  }

  /// Sign-out path: wait for any in-flight sync to finish (bounded), then push
  /// whatever is still pending so it isn't destroyed by the local wipe that
  /// follows. Returns whether the push pass actually ran and completed.
  Future<bool> flushPending(
      {Duration timeout = const Duration(seconds: 10)}) async {
    final deadline = DateTime.now().add(timeout);
    while (_running) {
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return pushOnly();
  }

  /// Defense-in-depth for cross-account leaks: refuse to sync while the local
  /// DB still belongs to a DIFFERENT account (residue of a sign-out that
  /// bypassed the logout wipe). The ownership guard normally wipes before the
  /// controller triggers a sync, but the debounced pushOnly path — and a
  /// guard failure — would otherwise push the previous account's pending
  /// rows into THIS account's cloud. Unset owner (guest-era data being
  /// adopted at first sign-in) is allowed.
  Future<bool> _ownsLocalDb(String uid) async {
    try {
      final owner = await _db.getSetting('dbOwnerUid');
      return owner == null || owner.isEmpty || owner == uid;
    } catch (_) {
      // Fail closed: better a skipped sync than the wrong account's upload.
      return false;
    }
  }

  /// Whether the session this run started for still exists: [uid] is still the
  /// signed-in user AND the session generation hasn't moved on (bumped by every
  /// auth change and local wipe). Checked after every network await and before
  /// every local write: sign-out wipes the local DB, and a pull/push that
  /// resolves after that must not write the old account's rows (or watermarks)
  /// back into the freshly-wiped database — they would then sync into the NEXT
  /// account's cloud. The uid check alone misses a same-account
  /// sign-out→sign-in within the run's lifetime; the generation doesn't.
  bool _live(String uid, int gen) =>
      _auth.currentUser?.uid == uid && _gen.isCurrent(gen);

  // Run the collections concurrently — each is an independent network call, so
  // the whole sync takes about as long as the slowest one instead of the sum.
  Future<void> _pushAll(String uid, int gen) => Future.wait([
        _pushTransactions(uid, gen),
        _pushAccounts(uid, gen),
        _pushCategories(uid, gen),
        _pushSlips(uid, gen),
        _pushBudgets(uid, gen),
        _pushTags(uid, gen),
        _pushRecurringRules(uid, gen),
        _pushSettings(uid, gen),
      ]);

  Future<void> _pullAll(String uid, int gen) => Future.wait([
        _pullAccounts(uid, gen),
        _pullCategories(uid, gen),
        _pullTags(uid, gen),
        _pullTransactions(uid, gen),
        _pullBudgets(uid, gen),
        _pullSlips(uid, gen),
        _pullRecurringRules(uid, gen),
        _pullSettings(uid, gen),
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
    // When the edit reached the cloud — distinct from `updatedAt` (when it was
    // made). The pull cursor advances on THIS field: a device coming back from
    // weeks offline pushes docs whose updatedAt is far in the past, and a
    // cursor keyed on updatedAt would never fetch them on other devices.
    map['pushedAt'] = DateTime.now().millisecondsSinceEpoch;
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

  Future<void> _pushTransactions(String uid, int gen) async {
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
      if (!_live(uid, gen)) return;
      // Compare-and-set on the updatedAt read at push time: an edit made while
      // this upload was in flight keeps the row pending instead of being
      // stamped synced (and never uploaded).
      await _db.markTransactionSynced(r.id, r.updatedAt);
    }));
  }

  Future<void> _pushAccounts(String uid, int gen) async {
    final col = _col(uid, 'accounts');
    await Future.wait((await _db.pendingAccounts()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.accountToMap(r));
      if (!_live(uid, gen)) return;
      await _db.markAccountSynced(r.id, r.updatedAt);
    }));
  }

  Future<void> _pushCategories(String uid, int gen) async {
    final col = _col(uid, 'categories');
    await Future.wait((await _db.pendingCategories()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.categoryToMap(r));
      if (!_live(uid, gen)) return;
      await _db.markCategorySynced(r.id, r.updatedAt);
    }));
  }

  Future<void> _pushSlips(String uid, int gen) async {
    final col = _col(uid, 'slips');
    await Future.wait((await _db.pendingSlips()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.slipToMap(r));
      if (!_live(uid, gen)) return;
      await _db.markSlipSynced(r.id, r.updatedAt);
    }));
  }

  Future<void> _pushBudgets(String uid, int gen) async {
    final col = _col(uid, 'budgets');
    await Future.wait((await _db.pendingBudgets()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.budgetToMap(r));
      if (!_live(uid, gen)) return;
      await _db.markBudgetSynced(r.id, r.updatedAt);
    }));
  }

  Future<void> _pushTags(String uid, int gen) async {
    final col = _col(uid, 'tags');
    await Future.wait((await _db.pendingTags()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.tagToMap(r));
      if (!_live(uid, gen)) return;
      await _db.markTagSynced(r.id, r.updatedAt);
    }));
  }

  Future<void> _pushRecurringRules(String uid, int gen) async {
    final col = _col(uid, 'recurringRules');
    await Future.wait((await _db.pendingRecurringRules()).map((r) async {
      await _pushDoc(col.doc(r.id), FirestoreMappers.recurringRuleToMap(r));
      if (!_live(uid, gen)) return;
      await _db.markRecurringRuleSynced(r.id, r.updatedAt);
    }));
  }

  /// Upload profile & per-user preference settings (see
  /// [AppDatabase.syncedSettingsKeys]) — one doc per key, LWW on `updatedAt`
  /// like every other collection. Without this, a profile edit lives only in
  /// the local key/value table, which the sign-out wipe destroys.
  Future<void> _pushSettings(String uid, int gen) async {
    final col = _col(uid, 'settings');
    await Future.wait((await _db.pendingSyncedSettings()).map((r) async {
      await _pushDoc(col.doc(r.key), {
        'value': r.value,
        'updatedAt': r.updatedAt,
      });
      if (!_live(uid, gen)) return;
      // Marker CAS: an edit made while this upload was in flight bumps the
      // row's updatedAt past this marker, keeping the key pending.
      await _db.markSettingPushed(r.key, r.updatedAt);
    }));
  }

  // ---- Pull (incremental, last-write-wins; deleted:true rows soft-delete) ---

  /// Fetch only docs that REACHED THE CLOUD since this collection's watermark
  /// (minus the clock-skew [_pullMargin]). Cursoring on `pushedAt` instead of
  /// `updatedAt` means a doc uploaded weeks after it was edited (a device that
  /// was offline that long) still lands inside every other device's window.
  ///
  /// A watermark of 0 (fresh device, post-wipe, or the one-time key-version
  /// reset) fetches the whole collection.
  ///
  /// Incremental pulls run TWO range queries and merge by doc id: `pushedAt`
  /// is the real cursor, but a Firestore range query never returns docs
  /// missing the queried field — and a peer still running an app version
  /// that predates `pushedAt` keeps writing such docs, which would otherwise
  /// be invisible to this device forever. The `updatedAt` query (every doc
  /// has it) covers those until the whole fleet is upgraded; overlap between
  /// the two result sets is deduped here.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _incrementalPull(
    String uid,
    String name,
  ) async {
    final watermark = await _db.pullWatermark(name);
    if (watermark <= 0) return (await _col(uid, name).get()).docs;
    final since = watermark - _pullMargin.inMilliseconds;
    final results = await Future.wait([
      _col(uid, name).where('pushedAt', isGreaterThan: since).get(),
      _col(uid, name).where('updatedAt', isGreaterThan: since).get(),
    ]);
    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final snap in results) {
      for (final doc in snap.docs) {
        byId[doc.id] = doc;
      }
    }
    return byId.values.toList();
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

  Future<void> _pullAccounts(String uid, int gen) async {
    final docs = await _incrementalPull(uid, 'accounts');
    if (docs.isEmpty || !_live(uid, gen)) return;
    final localUpdated = await _db.accountsUpdatedAt();
    final rows = <AccountsCompanion>[];
    var maxUpdated = 0;
    for (final doc in docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      // Cursor tracks pushedAt (falling back to updatedAt for legacy docs,
      // which only ever arrive via a watermark-0 full pull).
      final remotePushed = (data['pushedAt'] as num?)?.toInt() ?? remoteUpdated;
      if (remotePushed > maxUpdated) maxUpdated = remotePushed;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.accountFromMap(doc.id, data));
      }
    }
    if (!_live(uid, gen)) return;
    if (rows.isNotEmpty) await _db.batchUpsertAccounts(rows);
    if (!_live(uid, gen)) return;
    await _saveWatermark('accounts', maxUpdated);
  }

  Future<void> _pullCategories(String uid, int gen) async {
    final docs = await _incrementalPull(uid, 'categories');
    if (docs.isEmpty || !_live(uid, gen)) return;
    final localUpdated = await _db.categoriesUpdatedAt();
    final rows = <CategoriesCompanion>[];
    var maxUpdated = 0;
    for (final doc in docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      // Cursor tracks pushedAt (falling back to updatedAt for legacy docs,
      // which only ever arrive via a watermark-0 full pull).
      final remotePushed = (data['pushedAt'] as num?)?.toInt() ?? remoteUpdated;
      if (remotePushed > maxUpdated) maxUpdated = remotePushed;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.categoryFromMap(doc.id, data));
      }
    }
    if (!_live(uid, gen)) return;
    if (rows.isNotEmpty) await _db.batchUpsertCategories(rows);
    if (!_live(uid, gen)) return;
    await _saveWatermark('categories', maxUpdated);
  }

  Future<void> _pullTags(String uid, int gen) async {
    final docs = await _incrementalPull(uid, 'tags');
    if (docs.isEmpty || !_live(uid, gen)) return;
    final localUpdated = await _db.tagsUpdatedAt();
    final rows = <TagsCompanion>[];
    var maxUpdated = 0;
    for (final doc in docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      // Cursor tracks pushedAt (falling back to updatedAt for legacy docs,
      // which only ever arrive via a watermark-0 full pull).
      final remotePushed = (data['pushedAt'] as num?)?.toInt() ?? remoteUpdated;
      if (remotePushed > maxUpdated) maxUpdated = remotePushed;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.tagFromMap(doc.id, data));
      }
    }
    if (!_live(uid, gen)) return;
    if (rows.isNotEmpty) await _db.batchUpsertTags(rows);
    if (!_live(uid, gen)) return;
    await _saveWatermark('tags', maxUpdated);
  }

  Future<void> _pullTransactions(String uid, int gen) async {
    final docs = await _incrementalPull(uid, 'transactions');
    if (docs.isEmpty || !_live(uid, gen)) return;
    // One query for all local updatedAt instead of a read per row.
    final localUpdated = await _db.transactionsUpdatedAt();
    final rows = <TransactionsCompanion>[];
    final tagWrites = <MapEntry<String, List<String>>>[];
    var maxUpdated = 0;
    for (final doc in docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      // Cursor tracks pushedAt (falling back to updatedAt for legacy docs,
      // which only ever arrive via a watermark-0 full pull).
      final remotePushed = (data['pushedAt'] as num?)?.toInt() ?? remoteUpdated;
      if (remotePushed > maxUpdated) maxUpdated = remotePushed;
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
    if (!_live(uid, gen)) return;
    if (rows.isNotEmpty) await _db.batchUpsertTransactions(rows);
    for (final w in tagWrites) {
      if (!_live(uid, gen)) return;
      await _db.setTransactionTags(w.key, w.value);
    }
    if (!_live(uid, gen)) return;
    await _saveWatermark('transactions', maxUpdated);
  }

  Future<void> _pullBudgets(String uid, int gen) async {
    final docs = await _incrementalPull(uid, 'budgets');
    if (docs.isEmpty || !_live(uid, gen)) return;
    final localUpdated = await _db.budgetsUpdatedAt();
    final rows = <BudgetsCompanion>[];
    var maxUpdated = 0;
    for (final doc in docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      // Cursor tracks pushedAt (falling back to updatedAt for legacy docs,
      // which only ever arrive via a watermark-0 full pull).
      final remotePushed = (data['pushedAt'] as num?)?.toInt() ?? remoteUpdated;
      if (remotePushed > maxUpdated) maxUpdated = remotePushed;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.budgetFromMap(doc.id, data));
      }
    }
    if (!_live(uid, gen)) return;
    if (rows.isNotEmpty) await _db.batchUpsertBudgets(rows);
    if (!_live(uid, gen)) return;
    await _saveWatermark('budgets', maxUpdated);
  }

  Future<void> _pullSlips(String uid, int gen) async {
    final docs = await _incrementalPull(uid, 'slips');
    if (docs.isEmpty || !_live(uid, gen)) return;
    final localUpdated = await _db.slipsUpdatedAt();
    final rows = <SlipsCompanion>[];
    var maxUpdated = 0;
    for (final doc in docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      // Cursor tracks pushedAt (falling back to updatedAt for legacy docs,
      // which only ever arrive via a watermark-0 full pull).
      final remotePushed = (data['pushedAt'] as num?)?.toInt() ?? remoteUpdated;
      if (remotePushed > maxUpdated) maxUpdated = remotePushed;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.slipFromMap(doc.id, data));
      }
    }
    if (!_live(uid, gen)) return;
    if (rows.isNotEmpty) await _db.batchUpsertSlips(rows);
    if (!_live(uid, gen)) return;
    await _saveWatermark('slips', maxUpdated);
  }

  Future<void> _pullRecurringRules(String uid, int gen) async {
    final docs = await _incrementalPull(uid, 'recurringRules');
    if (docs.isEmpty || !_live(uid, gen)) return;
    final localUpdated = await _db.recurringRulesUpdatedAt();
    final rows = <RecurringRulesCompanion>[];
    var maxUpdated = 0;
    for (final doc in docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      // Cursor tracks pushedAt (falling back to updatedAt for legacy docs,
      // which only ever arrive via a watermark-0 full pull).
      final remotePushed = (data['pushedAt'] as num?)?.toInt() ?? remoteUpdated;
      if (remotePushed > maxUpdated) maxUpdated = remotePushed;
      final localUpdatedAt = localUpdated[doc.id];
      if (_isAbsentTombstone(data, localUpdatedAt)) continue;
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.recurringRuleFromMap(doc.id, data));
      }
    }
    if (!_live(uid, gen)) return;
    if (rows.isNotEmpty) await _db.batchUpsertRecurringRules(rows);
    if (!_live(uid, gen)) return;
    await _saveWatermark('recurringRules', maxUpdated);
  }

  /// Restore synced settings. The collection holds at most a handful of docs
  /// (one per key in [AppDatabase.syncedSettingsKeys]), so it is always fetched
  /// whole — no watermark cursor to maintain. Per-key last-write-wins against
  /// the local row's `updatedAt`, so a pending local edit (newer stamp) is
  /// never overwritten by a stale cloud value.
  Future<void> _pullSettings(String uid, int gen) async {
    final docs = (await _col(uid, 'settings').get()).docs;
    if (docs.isEmpty || !_live(uid, gen)) return;
    final local = {
      for (final r in await _db.getAllSettings()) r.key: r.updatedAt,
    };
    for (final doc in docs) {
      // Only known keys: junk or future keys in the cloud must not be able to
      // plant arbitrary rows in the local table.
      if (!AppDatabase.syncedSettingsKeys.contains(doc.id)) continue;
      final data = doc.data();
      // Tolerant types: `ultraUntil` is written BY HAND in the Firebase
      // console — a value typed as a number or an updatedAt entered as a
      // Timestamp must skip this doc, not throw and fail the whole pull
      // (which would gate the scanner forever for that user).
      final value = data['value'];
      if (value is! String) continue;
      final rawUpdated = data['updatedAt'];
      final remoteUpdated = rawUpdated is num ? rawUpdated.toInt() : 0;
      final localUpdated = local[doc.id];
      if (localUpdated != null && remoteUpdated <= localUpdated) continue;
      if (!_live(uid, gen)) return;
      await _db.upsertPulledSetting(doc.id, value, remoteUpdated);
      // The pulled value is by definition in the cloud already — mark it
      // pushed so the push pass doesn't immediately re-upload it.
      await _db.markSettingPushed(doc.id, remoteUpdated);
    }
  }
}
