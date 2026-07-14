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

    test('short keywords match at word boundaries only', () {
      // Substring false-positives import the whole album and burn quota.
      expect(SlipImporter.isSlipAlbumName('Bookmarks'), isFalse); // ⊅ kma
      expect(SlipImporter.isSlipAlbumName('Cities'), isFalse); // ⊅ citi
      expect(SlipImporter.isSlipAlbumName('Prompts'), isFalse); // ⊅ prompt
      expect(SlipImporter.isSlipAlbumName('Sedimentary'), isFalse); // ⊅ dime
      // The real apps still match.
      expect(SlipImporter.isSlipAlbumName('KMA'), isTrue);
      expect(SlipImporter.isSlipAlbumName('KMA Krungsri'), isTrue);
      expect(SlipImporter.isSlipAlbumName('Citibank TH'), isTrue);
      expect(SlipImporter.isSlipAlbumName('PromptPay'), isTrue);
      expect(SlipImporter.isSlipAlbumName('Dime!'), isTrue);
    });

    test('bounded keywords still match a brand concatenated with a suffix', () {
      // Some apps save straight into "<Brand><Suffix>" with no delimiter at
      // all — a digit run (year/version) or a camelCase boundary. These must
      // still match; only an ordinary lowercase word continuation (the
      // Bookmarks/Cities/Sedimentary case above) should not.
      expect(SlipImporter.isSlipAlbumName('KMA2024'), isTrue);
      expect(SlipImporter.isSlipAlbumName('DimeWallet'), isTrue);
      expect(SlipImporter.isSlipAlbumName('CitiMobile'), isTrue);
      expect(SlipImporter.isSlipAlbumName('PromptExpress'), isTrue);
      // But a lowercase continuation right after the fragment (no case-shift,
      // no digit) still reads as an ordinary word, not a brand suffix.
      expect(SlipImporter.isSlipAlbumName('kmarathon'), isFalse);
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
        'the device cursor wins over a NEWER watermark — an error holdback '
        'must be retried, and another device\'s sync must not skip this '
        'device\'s own unread backlog', () {
      // A photo this device failed to OCR is deliberately held BEFORE the
      // cursor for a retry; another device's newer watermark syncing in must
      // not jump this device's cutoff past that unread backlog. (Quota-
      // blocked photos get no such holdback — see the isBackfillPhoto/
      // quotaReached tests: once the quota trips, the cursor keeps advancing
      // and those specific photos are simply never retroactively imported.)
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
