import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/features/slip/data/slip_importer.dart';

void main() {
  group('SlipImporter.isSlipAlbumName', () {
    test('matches MAKE by KBank in all its folder-name forms', () {
      expect(SlipImporter.isSlipAlbumName('MAKE'), isTrue);
      expect(SlipImporter.isSlipAlbumName('MAKE by KBank'), isTrue);
      expect(SlipImporter.isSlipAlbumName('MAKEbyKBank'), isTrue);
      expect(SlipImporter.isSlipAlbumName('make_kbank'), isTrue);
    });

    test('matches other Thai bank / e-wallet albums', () {
      expect(SlipImporter.isSlipAlbumName('K PLUS'), isTrue);
      expect(SlipImporter.isSlipAlbumName('Krungthai NEXT'), isTrue);
      expect(SlipImporter.isSlipAlbumName('SCB'), isTrue);
      expect(SlipImporter.isSlipAlbumName('TrueMoney'), isTrue);
    });

    test('does not match unrelated albums (incl. the "makeup" trap)', () {
      expect(SlipImporter.isSlipAlbumName('Makeup'), isFalse);
      expect(SlipImporter.isSlipAlbumName('Camera'), isFalse);
      expect(SlipImporter.isSlipAlbumName('Pictures'), isFalse);
      expect(SlipImporter.isSlipAlbumName('Screenshots'), isFalse);
    });
  });

  group('SlipImporter.effectiveCutoff', () {
    test('with nothing read yet, reads from the start of the current month',
        () {
      final now = DateTime(2026, 7, 4, 12);
      expect(SlipImporter.effectiveCutoff(now), DateTime(2026, 7));
    });

    test('never reaches back before the current month', () {
      // Watermark / read-up-to from June must not pull an August scan into
      // July — slips are only ever read from the month the scan runs in.
      final now = DateTime(2026, 8, 2);
      final june = DateTime(2026, 6, 30, 23, 59).millisecondsSinceEpoch;
      expect(
        SlipImporter.effectiveCutoff(now, watermarkMs: june),
        DateTime(2026, 8),
      );
    });

    test('continues after the device cursor when one exists', () {
      final now = DateTime(2026, 7, 20);
      final imported = DateTime(2026, 7, 10, 9).millisecondsSinceEpoch;
      final readUpTo = DateTime(2026, 7, 15, 18).millisecondsSinceEpoch;
      expect(
        SlipImporter.effectiveCutoff(
          now,
          watermarkMs: imported,
          scannedUpToMs: readUpTo,
        ),
        DateTime(2026, 7, 15, 18),
      );
    });

    test(
        'the device cursor wins over a NEWER watermark — a quota/error '
        'holdback must be re-read after a top-up, not skipped', () {
      // Newest-first import: when quota ran out mid-batch the newest photos
      // were already imported (watermark = their time) while older ones were
      // blocked and the cursor deliberately held BEFORE them. The next scan
      // must start from the cursor, not jump to the watermark.
      final now = DateTime(2026, 7, 20);
      final newestImported = DateTime(2026, 7, 15, 18).millisecondsSinceEpoch;
      final heldBackCursor = DateTime(2026, 7, 10, 9).millisecondsSinceEpoch;
      expect(
        SlipImporter.effectiveCutoff(
          now,
          watermarkMs: newestImported,
          scannedUpToMs: heldBackCursor,
        ),
        DateTime(2026, 7, 10, 9),
      );
    });

    test('watermark is the fallback when the device has no cursor yet', () {
      // Fresh install / post-restore: no per-device cursor, so the synced
      // newest-imported-slip time keeps the scan from re-reading the month.
      final now = DateTime(2026, 7, 20);
      final imported = DateTime(2026, 7, 10, 9).millisecondsSinceEpoch;
      expect(
        SlipImporter.effectiveCutoff(now, watermarkMs: imported),
        DateTime(2026, 7, 10, 9),
      );
    });
  });

  group('SlipImporter.isBackfillPhoto', () {
    final cutoff = DateTime(2026, 7, 14).millisecondsSinceEpoch;

    test('photos taken before the cutoff import free', () {
      final signupNight = DateTime(2026, 7, 13, 23, 59).millisecondsSinceEpoch;
      expect(SlipImporter.isBackfillPhoto(signupNight, cutoff), isTrue);
    });

    test('the cutoff instant itself is counted', () {
      expect(SlipImporter.isBackfillPhoto(cutoff, cutoff), isFalse);
    });

    test('unknown photo time (epoch 0) is never backfill', () {
      expect(SlipImporter.isBackfillPhoto(0, cutoff), isFalse);
    });

    test('no cutoff (guest) → nothing is backfill', () {
      final t = DateTime(2026, 7, 1).millisecondsSinceEpoch;
      expect(SlipImporter.isBackfillPhoto(t, 0), isFalse);
    });
  });

  group('SlipImporter.albumScanId', () {
    test('attributes a bank album to its catalog id', () {
      expect(SlipImporter.albumScanId('K PLUS'), 'kbank');
      expect(SlipImporter.albumScanId('MAKE'), 'make');
      expect(SlipImporter.albumScanId('MAKE by KBank'), 'make');
      expect(SlipImporter.albumScanId('Krungthai NEXT'), 'ktb');
      expect(SlipImporter.albumScanId('SCB EASY'), 'scb');
      expect(SlipImporter.albumScanId('ธอส'), 'ghb');
      expect(SlipImporter.albumScanId('เป๋าตัง'), 'paotang');
    });

    test('returns null for generic albums not tied to a catalog bank', () {
      expect(SlipImporter.albumScanId('Slip'), isNull);
      expect(SlipImporter.albumScanId('Screenshots'), isNull);
    });
  });
}
