import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show PlatformException;

/// Outcome of redeeming a friend's code.
enum RedeemResult {
  success,

  /// The entered code is one of the caller's own candidate codes.
  ownCode,
  notFound,

  /// This account already redeemed a code (once ever).
  alreadyRedeemed,

  /// This account's own code has been redeemed by someone — it is "old" and
  /// can only invite, never redeem.
  alreadyReferrer,

  /// This physical device already performed a redemption (any account).
  deviceUsed,
  failed,
}

/// Referral codes that grant permanent Pro credits (+300 each side).
///
/// `referralCodes/{code}` is published by its owner and readable by any
/// signed-in user. A redemption is ONE atomic batch, written by the redeemer:
///
///   referralCodes/{code}/redemptions/{redeemerUid}   (v: 2 — the credit unit)
///   redeemers/{redeemerUid}     one-ever lock + the redeemer's own +300 proof
///   redeemedDevices/{hash}      one-per-physical-device lock
///   referrers/{ownerUid}        the owner's "old" marker (only when absent)
///
/// Security rules verify the whole shape with getAfter/existsAfter, so none
/// of the docs can be created alone and the new/old matrix (redeemer must be
/// new; either side's first match makes them old) is enforced server-side.
/// The owner's +300-per-friend is derived by counting v2 redemption docs —
/// there is no mutable credit counter anywhere.
class ReferralService {
  ReferralService(this._fs);

  final FirebaseFirestore _fs;

  /// Codes avoid look-alike characters (0/O, 1/I/L) — they get read aloud and
  /// typed by hand.
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// A user's referral code, derived deterministically from their uid so it
  /// survives reinstalls with no extra storage. [attempt] > 0 walks further
  /// down the hash on the (astronomically unlikely) collision with another
  /// user's code.
  static String codeForUid(String uid, {int attempt = 0}) {
    final digest = sha256.convert(utf8.encode('moneybun-referral:$uid')).bytes;
    final start = attempt * 6;
    final chars = List.generate(6, (i) {
      final byte = digest[(start + i) % digest.length];
      return _alphabet[byte % _alphabet.length];
    });
    return chars.join();
  }

  /// Publish my code so friends can redeem it. Idempotent; returns the code
  /// that ended up mine (normally attempt 0). If a different user already owns
  /// the derived code (hash collision), walks to the next candidate.
  Future<String> publishMyCode(String uid) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      final code = codeForUid(uid, attempt: attempt);
      final doc = _fs.collection('referralCodes').doc(code);
      final snap = await doc.get();
      if (!snap.exists) {
        await doc.set({
          'ownerUid': uid,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
        return code;
      }
      if (snap.data()?['ownerUid'] == uid) return code;
    }
    // Four straight collisions can't realistically happen; fall back to the
    // primary code so the UI still shows something stable.
    return codeForUid(uid);
  }

  /// Whether [e] is a Firestore permission denial. Aggregate (count) queries
  /// in cloud_firestore surface rules denials as a raw [PlatformException]
  /// (code 'firebase_firestore', details {code: permission-denied}) instead
  /// of a [FirebaseException] — both shapes must be recognised.
  static bool isPermissionDenied(Object e) {
    if (e is FirebaseException) return e.code == 'permission-denied';
    if (e is PlatformException) {
      final details = e.details;
      if (details is Map && details['code'] == 'permission-denied') {
        return true;
      }
      return (e.message ?? '').contains('PERMISSION_DENIED');
    }
    return false;
  }

  /// Pure precheck → error mapping, split out for unit tests. Returns null
  /// when the redemption may proceed. Encodes the owner's 4-way matrix:
  /// the REDEEMER must be new (never redeemed, never been redeemed-from);
  /// the code owner may be new or old.
  static RedeemResult? classifyPrecheck({
    required bool codeExists,
    required bool isOwnCode,
    required bool iHaveRedeemed,
    required bool iWasReferred,
    required bool deviceTaken,
  }) {
    if (!codeExists) return RedeemResult.notFound;
    if (isOwnCode) return RedeemResult.ownCode;
    if (iHaveRedeemed) return RedeemResult.alreadyRedeemed;
    if (iWasReferred) return RedeemResult.alreadyReferrer;
    if (deviceTaken) return RedeemResult.deviceUsed;
    return null;
  }

  /// Redeem [rawCode] as [uid] from this [deviceHash]. Prechecks give real
  /// error reasons up front (a rules denial is an opaque PERMISSION_DENIED);
  /// the batch itself is still fully verified server-side. One retry after a
  /// denied commit re-runs the prechecks to classify races (e.g. the owner
  /// became old between read and write → retry without their marker).
  Future<RedeemResult> redeem(
    String rawCode,
    String uid,
    String deviceHash,
  ) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return RedeemResult.notFound;
    // Any of my own candidate codes is self-referral.
    for (var attempt = 0; attempt < 4; attempt++) {
      if (code == codeForUid(uid, attempt: attempt)) {
        return RedeemResult.ownCode;
      }
    }
    try {
      return await _attempt(code, uid, deviceHash, retriesLeft: 1);
    } catch (_) {
      // Network / rules denial that the prechecks couldn't classify.
      return RedeemResult.failed;
    }
  }

  Future<RedeemResult> _attempt(
    String code,
    String uid,
    String deviceHash, {
    required int retriesLeft,
  }) async {
    final codeDoc = _fs.collection('referralCodes').doc(code);
    final codeSnap = await codeDoc.get();
    final ownerUid = codeSnap.data()?['ownerUid'] as String?;
    final precheck = classifyPrecheck(
      codeExists: codeSnap.exists && ownerUid != null,
      isOwnCode: ownerUid == uid,
      iHaveRedeemed: (await _fs.collection('redeemers').doc(uid).get()).exists,
      iWasReferred: (await _fs.collection('referrers').doc(uid).get()).exists,
      deviceTaken:
          (await _fs.collection('redeemedDevices').doc(deviceHash).get())
              .exists,
    );
    if (precheck != null) return precheck;

    // The owner's old-marker goes in the batch only when they don't have one
    // yet (a create on an existing doc counts as an update and is denied).
    final ownerMarked =
        (await _fs.collection('referrers').doc(ownerUid!).get()).exists;

    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _fs.batch();
    batch.set(codeDoc.collection('redemptions').doc(uid), {
      'redeemerUid': uid,
      'deviceHash': deviceHash,
      'v': 2,
      'createdAt': now,
    });
    batch.set(_fs.collection('redeemers').doc(uid), {
      'code': code,
      'deviceHash': deviceHash,
      'createdAt': now,
    });
    batch.set(_fs.collection('redeemedDevices').doc(deviceHash), {
      'redeemerUid': uid,
      'createdAt': now,
    });
    if (!ownerMarked) {
      batch.set(_fs.collection('referrers').doc(ownerUid), {
        'code': code,
        'byUid': uid,
        'createdAt': now,
      });
    }
    try {
      await batch.commit();
      return RedeemResult.success;
    } catch (e) {
      // A denial here after clean prechecks is a race (someone else's write
      // landed in between). One re-run re-reads everything and either returns
      // the real reason or commits with the fresh state.
      if (isPermissionDenied(e) && retriesLeft > 0) {
        return _attempt(code, uid, deviceHash, retriesLeft: retriesLeft - 1);
      }
      rethrow;
    }
  }

  /// Number of new-scheme (v2) redemptions of [code] — the owner's referral
  /// credit units. Only readable for codes I own; a permission denial (not my
  /// code / unpublished candidate) counts as 0.
  Future<int> countNewRedemptions(String code) async {
    try {
      final agg = await _fs
          .collection('referralCodes')
          .doc(code)
          .collection('redemptions')
          .where('v', isEqualTo: 2)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (e) {
      // Not my code / unpublished candidate → rules deny the count. That is
      // a normal "no referrals on this candidate" answer, not an error.
      if (isPermissionDenied(e)) return 0;
      rethrow;
    }
  }

  /// Whether this account has redeemed a code (its own +300 proof).
  Future<bool> hasRedeemed(String uid) async =>
      (await _fs.collection('redeemers').doc(uid).get()).exists;

  /// Whether this account's code has ever been redeemed (old via inviting).
  Future<bool> hasReferred(String uid) async =>
      (await _fs.collection('referrers').doc(uid).get()).exists;
}
