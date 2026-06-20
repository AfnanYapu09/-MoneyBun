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

  group('SlipImporter.scanCutoff', () {
    test('always reads only the past 7 days (no watermark)', () {
      final now = DateTime(2026, 6, 20, 12);
      expect(
        SlipImporter.scanCutoff(now),
        now.subtract(const Duration(days: 7)),
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
