import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/data/local/database.dart';
import 'package:moneybun/data/repositories/settings_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Fake path_provider that serves a temp directory as the app documents dir,
/// so restoreAvatarPath can be exercised without a device.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docsPath);
  final String docsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => docsPath;
}

void main() {
  late AppDatabase db;
  late SettingsRepository repo;
  late Directory docs;

  const uid = 'Y3Q8o9welfbLLCMr0RdvvDLkaZw1';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SettingsRepository(db);
    docs = Directory.systemTemp.createTempSync('avatar_restore_test');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });

  tearDown(() async {
    await db.close();
    docs.deleteSync(recursive: true);
  });

  File writePhoto(String name) =>
      File(p.join(docs.path, name))..writeAsBytesSync([1, 2, 3]);

  test('restores the account photo after a sign-out wipe', () async {
    final photo = writePhoto('avatar_${uid}_1783869753813.jpg');
    // Simulate the sign-out: pointer wiped, file left behind.
    await repo.setAvatarPath(photo.path);
    await repo.resetUserData();
    expect((await repo.read()).avatarPath, isNull);

    await repo.restoreAvatarPath(uid);
    expect((await repo.read()).avatarPath, photo.path);
  });

  test('picks the newest photo when several exist', () async {
    writePhoto('avatar_${uid}_1000.jpg');
    final newest = writePhoto('avatar_${uid}_2000.jpg');
    await repo.restoreAvatarPath(uid);
    expect((await repo.read()).avatarPath, newest.path);
  });

  test('never restores another account\'s photo', () async {
    writePhoto('avatar_otherUser123_1000.jpg');
    writePhoto('avatar_1712345678901.jpg'); // legacy, no uid
    await repo.restoreAvatarPath(uid);
    expect((await repo.read()).avatarPath, isNull);
  });

  test('does not override an avatar that is already set', () async {
    final current = writePhoto('avatar_${uid}_2000.jpg');
    writePhoto('avatar_${uid}_9999.jpg');
    await repo.setAvatarPath(current.path);
    await repo.restoreAvatarPath(uid);
    expect((await repo.read()).avatarPath, current.path);
  });

  test('replaces a dangling pointer whose file is gone', () async {
    await repo.setAvatarPath(p.join(docs.path, 'deleted.jpg'));
    final photo = writePhoto('avatar_${uid}_3000.jpg');
    await repo.restoreAvatarPath(uid);
    expect((await repo.read()).avatarPath, photo.path);
  });

  test('is a no-op when no photos exist', () async {
    await repo.restoreAvatarPath(uid);
    expect((await repo.read()).avatarPath, isNull);
  });

  group('cloud avatar (avatarImage)', () {
    final photoBytes = [for (var i = 0; i < 64; i++) i];

    test('saveAvatarPhoto stores the file, pointer, and synced base64',
        () async {
      final picked = File(p.join(docs.path, 'picked.jpg'))
        ..writeAsBytesSync(photoBytes);
      await repo.saveAvatarPhoto(uid: uid, sourcePath: picked.path);

      final settings = await repo.read();
      expect(settings.avatarPath, isNotNull);
      expect(File(settings.avatarPath!).readAsBytesSync(), photoBytes);
      expect(p.basename(settings.avatarPath!), startsWith('avatar_${uid}_'));
      expect(
        await db.getSetting(SettingsKeys.avatarImage),
        base64Encode(photoBytes),
      );
    });

    test('avatarImage is in the synced-keys set and wiped on sign-out',
        () async {
      expect(
        AppDatabase.syncedSettingsKeys.contains(SettingsKeys.avatarImage),
        isTrue,
      );
      await repo.set(SettingsKeys.avatarImage, 'abc');
      await repo.resetUserData();
      expect(await db.getSetting(SettingsKeys.avatarImage), isNull);
    });

    test('syncAvatarFromCloud materialises a pulled photo on a fresh device',
        () async {
      // Simulate the sync engine pulling the doc from Firestore.
      await db.upsertPulledSetting(
        SettingsKeys.avatarImage,
        base64Encode(photoBytes),
        5000,
      );
      await repo.syncAvatarFromCloud(uid);

      final path = (await repo.read()).avatarPath;
      expect(path, p.join(docs.path, 'avatar_${uid}_5000.jpg'));
      expect(File(path!).readAsBytesSync(), photoBytes);
    });

    test('syncAvatarFromCloud replaces an older photo and cleans it up',
        () async {
      final oldPhoto = writePhoto('avatar_${uid}_1000.jpg');
      await repo.setAvatarPath(oldPhoto.path);
      await db.upsertPulledSetting(
        SettingsKeys.avatarImage,
        base64Encode(photoBytes),
        9000,
      );
      await repo.syncAvatarFromCloud(uid);

      expect(
        (await repo.read()).avatarPath,
        p.join(docs.path, 'avatar_${uid}_9000.jpg'),
      );
      expect(oldPhoto.existsSync(), isFalse);
    });

    test('syncAvatarFromCloud no-ops when the pointer is already current',
        () async {
      final picked = File(p.join(docs.path, 'picked.jpg'))
        ..writeAsBytesSync(photoBytes);
      await repo.saveAvatarPhoto(uid: uid, sourcePath: picked.path);
      final before = (await repo.read()).avatarPath;

      await repo.syncAvatarFromCloud(uid);
      expect((await repo.read()).avatarPath, before);
      expect(File(before!).existsSync(), isTrue);
    });

    test('syncAvatarFromCloud no-ops without an avatarImage row', () async {
      await repo.syncAvatarFromCloud(uid);
      expect((await repo.read()).avatarPath, isNull);
    });

    test('full round-trip: pick → sign-out+wipe (new device) → pull → restore',
        () async {
      final picked = File(p.join(docs.path, 'picked.jpg'))
        ..writeAsBytesSync(photoBytes);
      await repo.saveAvatarPhoto(uid: uid, sourcePath: picked.path);
      final cloudValue = await db.getSetting(SettingsKeys.avatarImage);

      // Sign-out wipe + lose every local file (reinstall / another device).
      await repo.resetUserData();
      for (final f in docs.listSync().whereType<File>()) {
        f.deleteSync();
      }

      // Next login's sync pulls the doc back, then the post-sync hook runs.
      await db.upsertPulledSetting(SettingsKeys.avatarImage, cloudValue!, 7777);
      await repo.syncAvatarFromCloud(uid);

      final path = (await repo.read()).avatarPath;
      expect(path, isNotNull);
      expect(File(path!).readAsBytesSync(), photoBytes);
    });
  });
}
