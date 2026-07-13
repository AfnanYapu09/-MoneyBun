import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/features/plan/data/referral_service.dart';

void main() {
  group('ReferralService.classifyPrecheck (new/old matrix)', () {
    RedeemResult? run({
      bool codeExists = true,
      bool isOwnCode = false,
      bool iHaveRedeemed = false,
      bool iWasReferred = false,
      bool deviceTaken = false,
    }) {
      return ReferralService.classifyPrecheck(
        codeExists: codeExists,
        isOwnCode: isOwnCode,
        iHaveRedeemed: iHaveRedeemed,
        iWasReferred: iWasReferred,
        deviceTaken: deviceTaken,
      );
    }

    test('new redeems new or old owner → proceeds (matrix ✓ cells)', () {
      // The owner's status is not an input at all: new-invites-new and
      // old-invites-new are both allowed.
      expect(run(), isNull);
    });

    test('a redeemer who already redeemed is old → blocked', () {
      expect(run(iHaveRedeemed: true), RedeemResult.alreadyRedeemed);
    });

    test('a redeemer whose code was redeemed is old → blocked', () {
      expect(run(iWasReferred: true), RedeemResult.alreadyReferrer);
    });

    test('unknown code', () {
      expect(run(codeExists: false), RedeemResult.notFound);
    });

    test('own code', () {
      expect(run(isOwnCode: true), RedeemResult.ownCode);
    });

    test('device already used', () {
      expect(run(deviceTaken: true), RedeemResult.deviceUsed);
    });

    test('most specific account state wins over the device lock', () {
      expect(
        run(iHaveRedeemed: true, deviceTaken: true),
        RedeemResult.alreadyRedeemed,
      );
    });
  });
}
