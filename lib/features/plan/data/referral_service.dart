import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Outcome of redeeming a friend's code.
enum RedeemResult { success, ownCode, notFound, failed }

/// Referral codes that unlock Pro: `referralCodes/{code}` is published by
/// its owner and readable by any signed-in user; a friend redeems by writing
/// `referralCodes/{code}/redemptions/{redeemerUid}_{month}`. Both sides then
/// hold Pro for that month — the redeemer immediately, the owner the next
/// time their app checks for redemptions (every completed sync).
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

  /// Redeem [rawCode] for [month] ('YYYY-MM') as [uid]. On success the caller
  /// grants Pro locally (setProMonth) — the code owner's side is picked up
  /// by their own [hasRedemptionForMonth] poll.
  Future<RedeemResult> redeem(String rawCode, String uid, String month) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return RedeemResult.notFound;
    // Any of my own candidate codes is self-referral.
    for (var attempt = 0; attempt < 4; attempt++) {
      if (code == codeForUid(uid, attempt: attempt)) {
        return RedeemResult.ownCode;
      }
    }
    try {
      final doc = _fs.collection('referralCodes').doc(code);
      final snap = await doc.get();
      if (!snap.exists) return RedeemResult.notFound;
      if (snap.data()?['ownerUid'] == uid) return RedeemResult.ownCode;
      await doc.collection('redemptions').doc('${uid}_$month').set({
        'redeemerUid': uid,
        'month': month,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      return RedeemResult.success;
    } on FirebaseException {
      return RedeemResult.failed;
    }
  }

  /// Whether anyone redeemed my code for [month] — the owner's side of the
  /// reward. One tiny query (limit 1) per check.
  Future<bool> hasRedemptionForMonth(String myCode, String month) async {
    try {
      final snap = await _fs
          .collection('referralCodes')
          .doc(myCode)
          .collection('redemptions')
          .where('month', isEqualTo: month)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } on FirebaseException {
      return false;
    }
  }
}
