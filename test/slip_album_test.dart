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

    test('continues after the newest of watermark and read-up-to record', () {
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
