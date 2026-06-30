import 'package:cloud_firestore/cloud_firestore.dart';

import '../local/database.dart';
import 'auth_service.dart';
import 'firestore_mappers.dart';

/// Local-first sync. Drift is the source of truth. On [sync] we push every
/// locally-changed row to the signed-in user's Firestore collections, then pull
/// remote changes back, resolving conflicts last-write-wins by `updatedAt`.
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

  /// Full sync (push + pull). Returns true if it actually ran (user signed in).
  Future<bool> sync() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _running) return false;
    _running = true;
    try {
      await _pushAll(uid);
      await _pullAll(uid);
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
      ]);

  Future<void> _pullAll(String uid) => Future.wait([
        _pullAccounts(uid),
        _pullCategories(uid),
        _pullTags(uid),
        _pullTransactions(uid),
        _pullBudgets(uid),
        _pullSlips(uid),
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

  // ---- Pull (last-write-wins; deleted:true rows soft-delete locally) ------

  Future<void> _pullAccounts(String uid) async {
    final snap = await _col(uid, 'accounts').get();
    for (final doc in snap.docs) {
      final local = await _db.getAccount(doc.id);
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      if (local == null || remoteUpdated > local.updatedAt) {
        await _db
            .upsertAccount(FirestoreMappers.accountFromMap(doc.id, doc.data()));
      }
    }
  }

  Future<void> _pullCategories(String uid) async {
    final snap = await _col(uid, 'categories').get();
    for (final doc in snap.docs) {
      final local = await _db.getCategory(doc.id);
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      if (local == null || remoteUpdated > local.updatedAt) {
        await _db.upsertCategory(
            FirestoreMappers.categoryFromMap(doc.id, doc.data()));
      }
    }
  }

  Future<void> _pullTags(String uid) async {
    final snap = await _col(uid, 'tags').get();
    for (final doc in snap.docs) {
      final local = await _db.getTag(doc.id);
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      if (local == null || remoteUpdated > local.updatedAt) {
        await _db.upsertTag(FirestoreMappers.tagFromMap(doc.id, doc.data()));
      }
    }
  }

  Future<void> _pullTransactions(String uid) async {
    final snap = await _col(uid, 'transactions').get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final local = await _db.getTransaction(doc.id);
      final remoteUpdated = (data['updatedAt'] as num?)?.toInt() ?? 0;
      if (local == null || remoteUpdated > local.updatedAt) {
        await _db.upsertTransaction(
            FirestoreMappers.transactionFromMap(doc.id, data));
        final tagIds =
            (data['tagIds'] as List?)?.whereType<String>().toList() ??
                const <String>[];
        // A brand-new local row has no links to clear, so skip the link write
        // when there are no tags (the common case) — a big speed-up on the
        // first pull. For updates, always set so tag removals propagate.
        if (tagIds.isNotEmpty || local != null) {
          await _db.setTransactionTags(doc.id, tagIds);
        }
      }
    }
  }

  Future<void> _pullBudgets(String uid) async {
    final snap = await _col(uid, 'budgets').get();
    for (final doc in snap.docs) {
      final local = await _db.getBudget(doc.id);
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      if (local == null || remoteUpdated > local.updatedAt) {
        await _db
            .upsertBudget(FirestoreMappers.budgetFromMap(doc.id, doc.data()));
      }
    }
  }

  Future<void> _pullSlips(String uid) async {
    final snap = await _col(uid, 'slips').get();
    for (final doc in snap.docs) {
      final local = await _db.getSlip(doc.id);
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      if (local == null || remoteUpdated > local.updatedAt) {
        await _db.upsertSlip(FirestoreMappers.slipFromMap(doc.id, doc.data()));
      }
    }
  }
}
