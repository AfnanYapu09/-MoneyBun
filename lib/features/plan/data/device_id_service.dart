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
    try {
      if (Platform.isAndroid) {
        final id = await const AndroidId().getId();
        if (id != null && id.isNotEmpty) return id;
      }
    } catch (_) {
      // Fall through to the persisted fallback.
    }
    final existing = await _settings.getDeviceIdFallback();
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    await _settings.setDeviceIdFallback(generated);
    return generated;
  }
}
