import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/parsed_slip.dart';
import '../../domain/enums/enums.dart';

/// Client for the `verifySlip` Cloud Function, which proxies the EasySlip /
/// SlipOK verify API server-side (the API key never reaches the device).
class SlipVerifyApi {
  SlipVerifyApi(this._functions);

  final FirebaseFunctions _functions;

  /// Verify a slip by its QR [payload] (preferred — exact & cheap) or by an
  /// [imageBase64]. Returns a verified [ParsedSlip] with sender/receiver names
  /// that on-device Latin OCR cannot read.
  Future<ParsedSlip> verify({String? payload, String? imageBase64}) async {
    final callable = _functions.httpsCallable('verifySlip');
    final response = await callable.call<Map<String, dynamic>>({
      if (payload != null) 'payload': payload,
      if (imageBase64 != null) 'imageBase64': imageBase64,
    });
    final data = Map<String, dynamic>.from(response.data);

    final amount = data['amountCents'];
    final occurredMs = data['occurredAtMs'];
    return ParsedSlip(
      source: SlipSource.apiVerified,
      verified: data['verified'] == true,
      confidence: 1,
      bankCode: data['bankCode'] as String?,
      transRef: data['transRef'] as String?,
      amountCents: amount is num ? amount.toInt() : null,
      occurredAt: occurredMs is num
          ? DateTime.fromMillisecondsSinceEpoch(occurredMs.toInt())
          : null,
      senderName: data['senderName'] as String?,
      senderBank: data['senderBank'] as String?,
      receiverName: data['receiverName'] as String?,
      receiverBank: data['receiverBank'] as String?,
    );
  }
}
