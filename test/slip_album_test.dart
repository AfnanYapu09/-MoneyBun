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
}
