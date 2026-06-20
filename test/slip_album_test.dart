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

  group('SlipImporter.computeScanCutoff', () {
    final now = DateTime(2026, 6, 20, 12);
    final weekAgo = now.subtract(const Duration(days: 7));

    test('first scan (no watermark) reads only the past week', () {
      expect(SlipImporter.computeScanCutoff(now, null), weekAgo);
      expect(SlipImporter.computeScanCutoff(now, 0), weekAgo);
    });

    test('after a long absence still reads only the past week', () {
      final monthAgo = now.subtract(const Duration(days: 30));
      final cutoff = SlipImporter.computeScanCutoff(
        now,
        monthAgo.millisecondsSinceEpoch,
      );
      expect(cutoff, weekAgo); // clamped — never older than a week
    });

    test('frequent use reads only what is newer than the last read', () {
      final yesterday = now.subtract(const Duration(days: 1));
      final cutoff = SlipImporter.computeScanCutoff(
        now,
        yesterday.millisecondsSinceEpoch,
      );
      expect(cutoff, yesterday); // watermark is newer than a week ago
    });
  });

  group('SlipImporter.bankCodeForAlbumName', () {
    test('attributes a bank album to its BOT code', () {
      expect(SlipImporter.bankCodeForAlbumName('K PLUS'), '004');
      expect(SlipImporter.bankCodeForAlbumName('MAKE'), '004');
      expect(SlipImporter.bankCodeForAlbumName('MAKE by KBank'), '004');
      expect(SlipImporter.bankCodeForAlbumName('Krungthai NEXT'), '006');
      expect(SlipImporter.bankCodeForAlbumName('SCB EASY'), '014');
      expect(SlipImporter.bankCodeForAlbumName('TrueMoney'), 'TRUEMONEY');
    });

    test('returns null for e-wallet / generic albums with no bank code', () {
      expect(SlipImporter.bankCodeForAlbumName('เป๋าตัง'), isNull);
      expect(SlipImporter.bankCodeForAlbumName('ShopeePay'), isNull);
      expect(SlipImporter.bankCodeForAlbumName('Slip'), isNull);
    });
  });
}
