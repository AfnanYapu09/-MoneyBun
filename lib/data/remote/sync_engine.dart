import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/enums/enums.dart';
import '../local/database.dart';
import 'auth_service.dart';
import 'firestore_mappers.dart';

/// Local-first sync. Drift is the source of truth. On [sync] we push every
/// locally-changed row to the signed-in user's Firestore collections, then pull
/// remote changes back, resolving conflicts last-write-wins by `updatedAt`.
///
/// For a personal, single-user / multi-device app the collections are small, so
/// pull reads the whole collection and upserts only rows that are newer than the
/// local copy. Document id == row id, so no cursor bookkeeping is required.
class SyncEngine {
  SyncEngine(this._db, this._fs, this._auth);

  final AppDatabase _db;
  final FirebaseFirestore _fs;
  final AuthService _auth;

  bool _running = false;

  CollectionReference<Map<String, dynamic>> _col(String uid, String name) =>
      _fs.collection('users').doc(uid).collection(name);

  /// Returns true if a sync actually ran (i.e. the user is signed in).
  Future<bool> sync() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _running) return false;
    _running = true;
    try {
      await _pushTransactions(uid);
      await _pushAccounts(uid);
      await _pushCategories(uid);
      await _pushSlips(uid);

      await _pullAccounts(uid);
      await _pullCategories(uid);
      await _pullTransactions(uid);
      await _pullSlips(uid);
      return true;
    } finally {
      _running = false;
    }
  }

  // ---- Push --------------------------------------------------------------

  Future<void> _pushTransactions(String uid) async {
    final col = _col(uid, 'transactions');
    for (final r in await _db.pendingTransactions()) {
      if (r.syncStatus == SyncStatus.pendingDelete) {
        await col.doc(r.id).delete();
      } else {
        await col.doc(r.id).set(FirestoreMappers.transactionToMap(r));
      }
      await _db.markTransactionSynced(r.id);
    }
  }

  Future<void> _pushAccounts(String uid) async {
    final col = _col(uid, 'accounts');
    for (final r in await _db.pendingAccounts()) {
      if (r.syncStatus == SyncStatus.pendingDelete) {
        await col.doc(r.id).delete();
      } else {
        await col.doc(r.id).set(FirestoreMappers.accountToMap(r));
      }
      await _db.markAccountSynced(r.id);
    }
  }

  Future<void> _pushCategories(String uid) async {
    final col = _col(uid, 'categories');
    for (final r in await _db.pendingCategories()) {
      if (r.syncStatus == SyncStatus.pendingDelete) {
        await col.doc(r.id).delete();
      } else {
        await col.doc(r.id).set(FirestoreMappers.categoryToMap(r));
      }
      await _db.markCategorySynced(r.id);
    }
  }

  Future<void> _pushSlips(String uid) async {
    final col = _col(uid, 'slips');
    for (final r in await _db.pendingSlips()) {
      if (r.syncStatus == SyncStatus.pendingDelete) {
        await col.doc(r.id).delete();
      } else {
        await col.doc(r.id).set(FirestoreMappers.slipToMap(r));
      }
      await _db.markSlipSynced(r.id);
    }
  }

  // ---- Pull (last-write-wins) -------------------------------------------

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
    final locals = {for (final c in await _db.getCategories()) c.id: c};
    for (final doc in snap.docs) {
      final local = locals[doc.id];
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      if (local == null || remoteUpdated > local.updatedAt) {
        await _db.upsertCategory(
            FirestoreMappers.categoryFromMap(doc.id, doc.data()));
      }
    }
  }

  Future<void> _pullTransactions(String uid) async {
    final snap = await _col(uid, 'transactions').get();
    for (final doc in snap.docs) {
      final local = await _db.getTransaction(doc.id);
      final remoteUpdated = (doc.data()['updatedAt'] as num?)?.toInt() ?? 0;
      if (local == null || remoteUpdated > local.updatedAt) {
        await _db.upsertTransaction(
            FirestoreMappers.transactionFromMap(doc.id, doc.data()));
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
