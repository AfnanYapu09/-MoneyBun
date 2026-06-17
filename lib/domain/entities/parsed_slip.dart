import '../enums/enums.dart';

/// Result of the slip-reading pipeline: whatever could be extracted from a slip
/// image via QR + on-device OCR (and optionally the online verify API).
class ParsedSlip {
  const ParsedSlip({
    required this.source,
    this.imagePath,
    this.bankCode,
    this.transRef,
    this.qrPayload,
    this.amountCents,
    this.occurredAt,
    this.senderName,
    this.senderBank,
    this.receiverName,
    this.receiverBank,
    this.rawOcrText,
    this.confidence = 0,
    this.verified = false,
  });

  final SlipSource source;
  final String? imagePath;
  final String? bankCode;
  final String? transRef;
  final String? qrPayload;
  final int? amountCents;
  final DateTime? occurredAt;
  final String? senderName;
  final String? senderBank;
  final String? receiverName;
  final String? receiverBank;
  final String? rawOcrText;
  final double confidence;
  final bool verified;

  /// Whether there's enough to prefill the add form without forcing online verify.
  bool get isHighConfidence => amountCents != null && confidence >= 0.6;

  ParsedSlip copyWith({
    SlipSource? source,
    String? imagePath,
    String? bankCode,
    String? transRef,
    String? qrPayload,
    int? amountCents,
    DateTime? occurredAt,
    String? senderName,
    String? senderBank,
    String? receiverName,
    String? receiverBank,
    String? rawOcrText,
    double? confidence,
    bool? verified,
  }) {
    return ParsedSlip(
      source: source ?? this.source,
      imagePath: imagePath ?? this.imagePath,
      bankCode: bankCode ?? this.bankCode,
      transRef: transRef ?? this.transRef,
      qrPayload: qrPayload ?? this.qrPayload,
      amountCents: amountCents ?? this.amountCents,
      occurredAt: occurredAt ?? this.occurredAt,
      senderName: senderName ?? this.senderName,
      senderBank: senderBank ?? this.senderBank,
      receiverName: receiverName ?? this.receiverName,
      receiverBank: receiverBank ?? this.receiverBank,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      confidence: confidence ?? this.confidence,
      verified: verified ?? this.verified,
    );
  }
}
