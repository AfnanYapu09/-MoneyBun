import 'dart:convert';
import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/settings_repository.dart';

/// A stable, privacy-preserving id for THIS physical device, backing the
/// one-redemption-per-device referral lock. The raw ANDROID_ID never leaves
/// the device — only its salted sha256 hex (64 chars) is stored in Firestore.
///
/// ANDROID_ID is per-app-signing-key + per-user and survives reinstalls
/// (resets only on a factory reset) — exactly the persistence the lock needs.
/// (device_info_plus is NOT usable here: its `androidInfo.id` is Build.ID,
/// shared by every device on the same firmware.) On other platforms, or when
/// the id is unavailable, a random UUID is persisted in a DEVICE-level
/// settings key that intentionally survives sign-out.
class DeviceIdService {
  DeviceIdService(this._settings);

  final SettingsRepository _settings;

  String? _cached;

  Future<String> deviceHash() async {
    final cached = _cached;
    if (cached != null) return cached;
    final hash = hashOf(await _rawId());
    _cached = hash;
    return hash;
  }

  /// Salted hash, split out for tests.
  static String hashOf(String rawId) =>
      sha256.convert(utf8.encode('moneybun-device:$rawId')).toString();

  Future<String> _rawId() async {
    // Always attempt the real ANDROID_ID first (cheap: one platform-channel
    // call, no network) rather than short-circuiting on whatever is pinned —
    // a device that hit a ONE-OFF transient plugin failure on its very first
    // call used to pin a random UUID and be stuck on it forever, since the
    // pin was trusted unconditionally on every later call too. That UUID has
    // no relation to the hardware, so a reinstall (which loses the local pin)
    // would re-derive from the real ANDROID_ID instead and mint a SECOND,
    // different hash for the same physical device — silently defeating the
    // one-redemption-per-device lock this pinning exists for.
    //
    // Only write a new pin when the raw id actually needs to change — once
    // ANDROID_ID is obtained successfully, every later call gets the exact
    // same value back (it's stable across the app's lifetime) and this is a
    // no-op read, so this does NOT reintroduce the original "querying every
    // call risks two different hashes" problem: it only self-heals a bad
    // pin, it never overwrites a good one with something different.
    final pinned = await _settings.getDeviceIdFallback();
    String? live;
    if (Platform.isAndroid) {
      try {
        final id = await const AndroidId().getId();
        if (id != null && id.isNotEmpty) live = id;
      } catch (_) {
        // Transient failure — fall through to the pinned value below instead
        // of minting yet another random UUID on top of an existing one.
      }
    }
    final raw = live ?? pinned ?? const Uuid().v4();
    if (raw != pinned) await _settings.setDeviceIdFallback(raw);
    return raw;
  }
}
