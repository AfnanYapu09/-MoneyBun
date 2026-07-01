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
/// pull. For a personal, single-user / multi-device app the collections are
/// small, so pull reads the whole collection and upserts only rows newer than
/// the local copy. Document id == row id, so no cursor bookkeeping is required.
///
/// [pushOnly] uploads pending local changes without pulling — used by the
/// automatic on-change sync so frequent edits don't run up Firestore reads.
class SyncEngine {
  SyncEngine(this._db, this._fs, this._auth);

  final AppDatabase _db;
  final FirebaseFirestore _fs;
  final AuthService _auth;

  bool _running = false;

  CollectionReference<Map<String, dynamic>> _col(String uid, String name) =>
      _fs.collection('users').doc(uid).collection(name);

  /// Full sync (pull + push). Returns true if it actually ran (user signed in).
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
      await _pullAll(uid);
      await _pushAll(uid);
      return true;
    } finally {
      _running = false;
    }
  }

  /// Push pending local changes only (no pull). Cheap — no reads.
  Future<bool> pushOnly() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _running) return false;
    _running = true;
    try {
      await _pushAll(uid);
      return true;
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

  Future<void> _pushTransactions(String uid) async {
    final col = _col(uid, 'transactions');
    for (final r in await _db.pendingTransactions()) {
      final map = FirestoreMappers.transactionToMap(r);
      // Embed the tag links so they sync without a separate collection.
      map['tagIds'] = await _db.tagIdsForTransaction(r.id);
      await col.doc(r.id).set(map);
      await _db.markTransactionSynced(r.id);
    }
  }

  Future<void> _pushAccounts(String uid) async {
    final col = _col(uid, 'accounts');
    for (final r in await _db.pendingAccounts()) {
      await col.doc(r.id).set(FirestoreMappers.accountToMap(r));
      await _db.markAccountSynced(r.id);
    }
  }

  Future<void> _pushCategories(String uid) async {
    final col = _col(uid, 'categories');
    for (final r in await _db.pendingCategories()) {
      await col.doc(r.id).set(FirestoreMappers.categoryToMap(r));
      await _db.markCategorySynced(r.id);
    }
  }

  Future<void> _pushSlips(String uid) async {
    final col = _col(uid, 'slips');
    for (final r in await _db.pendingSlips()) {
      await col.doc(r.id).set(FirestoreMappers.slipToMap(r));
      await _db.markSlipSynced(r.id);
    }
  }

  Future<void> _pushBudgets(String uid) async {
    final col = _col(uid, 'budgets');
    for (final r in await _db.pendingBudgets()) {
      await col.doc(r.id).set(FirestoreMappers.budgetToMap(r));
      await _db.markBudgetSynced(r.id);
    }
  }

  Future<void> _pushTags(String uid) async {
    final col = _col(uid, 'tags');
    for (final r in await _db.pendingTags()) {
      await col.doc(r.id).set(FirestoreMappers.tagToMap(r));
      await _db.markTagSynced(r.id);
    }
  }

  Future<void> _pushRecurringRules(String uid) async {
    final col = _col(uid, 'recurringRules');
    for (final r in await _db.pendingRecurringRules()) {
      await col.doc(r.id).set(FirestoreMappers.recurringRuleToMap(r));
      await _db.markRecurringRuleSynced(r.id);
    }
  }

  // ---- Pull (last-write-wins; deleted:true rows soft-delete locally) ------

  Future<void> _pullAccounts(String uid) async {
    final snap = await _col(uid, 'accounts').get();
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.accountsUpdatedAt();
    final rows = <AccountsCompanion>[];
    for (final doc in snap.docs) {
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      final localUpdatedAt = localUpdated[doc.id];
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.accountFromMap(doc.id, doc.data()));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertAccounts(rows);
  }

  Future<void> _pullCategories(String uid) async {
    final snap = await _col(uid, 'categories').get();
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.categoriesUpdatedAt();
    final rows = <CategoriesCompanion>[];
    for (final doc in snap.docs) {
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      final localUpdatedAt = localUpdated[doc.id];
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.categoryFromMap(doc.id, doc.data()));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertCategories(rows);
  }

  Future<void> _pullTags(String uid) async {
    final snap = await _col(uid, 'tags').get();
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.tagsUpdatedAt();
    final rows = <TagsCompanion>[];
    for (final doc in snap.docs) {
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      final localUpdatedAt = localUpdated[doc.id];
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.tagFromMap(doc.id, doc.data()));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertTags(rows);
  }

  Future<void> _pullTransactions(String uid) async {
    final snap = await _col(uid, 'transactions').get();
    if (snap.docs.isEmpty) return;
    // One query for all local updatedAt instead of a read per row.
    final localUpdated = await _db.transactionsUpdatedAt();
    final rows = <TransactionsCompanion>[];
    final tagWrites = <MapEntry<String, List<String>>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      final localUpdatedAt = localUpdated[doc.id];
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
  }

  Future<void> _pullBudgets(String uid) async {
    final snap = await _col(uid, 'budgets').get();
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.budgetsUpdatedAt();
    final rows = <BudgetsCompanion>[];
    for (final doc in snap.docs) {
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      final localUpdatedAt = localUpdated[doc.id];
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.budgetFromMap(doc.id, doc.data()));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertBudgets(rows);
  }

  Future<void> _pullSlips(String uid) async {
    final snap = await _col(uid, 'slips').get();
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.slipsUpdatedAt();
    final rows = <SlipsCompanion>[];
    for (final doc in snap.docs) {
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      final localUpdatedAt = localUpdated[doc.id];
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.slipFromMap(doc.id, doc.data()));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertSlips(rows);
  }

  Future<void> _pullRecurringRules(String uid) async {
    final snap = await _col(uid, 'recurringRules').get();
    if (snap.docs.isEmpty) return;
    final localUpdated = await _db.recurringRulesUpdatedAt();
    final rows = <RecurringRulesCompanion>[];
    for (final doc in snap.docs) {
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      final localUpdatedAt = localUpdated[doc.id];
      if (localUpdatedAt == null || remoteUpdated > localUpdatedAt) {
        rows.add(FirestoreMappers.recurringRuleFromMap(doc.id, doc.data()));
      }
    }
    if (rows.isNotEmpty) await _db.batchUpsertRecurringRules(rows);
  }
}
