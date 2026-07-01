import '../../../core/constants/bank_codes.dart';

/// One EMVCo TLV field: a 2-char id, its value, and (for templates) children.
class TlvField {
  TlvField(this.id, this.value, [this.children = const []]);

  final String id;
  final String value;
  final List<TlvField> children;
}

/// Structured data pulled from a Thai "Slip Verify" mini-QR.
class SlipQrData {
  const SlipQrData({
    required this.crcValid,
    this.bankCode,
    this.transRef,
    this.rawFields = const [],
  });

  final bool crcValid;
  final String? bankCode;
  final String? transRef;
  final List<TlvField> rawFields;
}

/// A hand-written EMVCo TLV parser for the Thai Slip-Verify mini-QR.
///
/// The mini-QR encodes only a sending-bank code + transaction reference (plus a
/// CRC16 checksum in tag `63`). No maintained Dart package PARSES this (the
/// PromptPay packages only generate QR), so we parse it ourselves. This is pure
/// Dart and fully unit-testable.
class EmvTlvParser {
  const EmvTlvParser._();

  /// Parse a flat list of top-level TLV fields, recursing into nested templates.
  static List<TlvField> parseFields(String data) {
    final fields = <TlvField>[];
    var i = 0;
    while (i + 4 <= data.length) {
      final id = data.substring(i, i + 2);
      final lenStr = data.substring(i + 2, i + 4);
      final len = int.tryParse(lenStr);
      if (len == null) break;
      final start = i + 4;
      final end = start + len;
      if (end > data.length) break;
      final value = data.substring(start, end);
      fields.add(TlvField(id, value, _maybeChildren(value)));
      i = end;
    }
    return fields;
  }

  /// Recurse only when the value parses cleanly and fully as nested TLV.
  static List<TlvField> _maybeChildren(String value) {
    if (value.length < 4) return const [];
    final children = <TlvField>[];
    var i = 0;
    while (i + 4 <= value.length) {
      final lenStr = value.substring(i + 2, i + 4);
      final len = int.tryParse(lenStr);
      if (len == null) return const [];
      final end = i + 4 + len;
      if (end > value.length) return const [];
      children.add(
        TlvField(
          value.substring(i, i + 2),
          value.substring(i + 4, end),
          const [],
        ),
      );
      i = end;
    }
    // Only treat as a template if it consumed the whole value cleanly.
    return i == value.length && children.length > 1 ? children : const [];
  }

  /// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF) over the ASCII bytes —
  /// the algorithm EMVCo/BOT uses for the tag `63` checksum.
  static int crc16(String input) {
    var crc = 0xFFFF;
    for (final code in input.codeUnits) {
      crc ^= code << 8;
      for (var bit = 0; bit < 8; bit++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }
        crc &= 0xFFFF;
      }
    }
    return crc;
  }

  /// Validate the trailing CRC. The checksum is computed over everything up to
  /// and including the `6304` marker; the last 4 chars are the hex CRC.
  static bool validateCrc(String payload) {
    final marker = payload.lastIndexOf('6304');
    if (marker < 0 || marker + 8 != payload.length) return false;
    final base = payload.substring(0, marker + 4);
    final expected = payload.substring(marker + 4).toUpperCase();
    final actual = crc16(base).toRadixString(16).toUpperCase().padLeft(4, '0');
    return actual == expected;
  }

  /// Parse the slip QR into [SlipQrData], pulling out the bank code and
  /// transaction reference heuristically from the (possibly nested) fields.
  static SlipQrData parseSlip(String payload) {
    final fields = parseFields(payload);
    final flat = _flatten(fields);

    String? bankCode;
    String? transRef;

    for (final f in flat) {
      final v = f.value.trim();
      // A 3-digit value matching a known bank is the sending bank code.
      if (bankCode == null && v.length == 3 && BankCodes.byCode(v) != null) {
        bankCode = v;
      }
      // The transaction reference: a longer alphanumeric token with digits.
      if (transRef == null &&
          v.length >= 10 &&
          v.length <= 30 &&
          RegExp(r'^[A-Za-z0-9]+$').hasMatch(v) &&
          RegExp(r'\d').hasMatch(v)) {
        transRef = v;
      }
    }

    return SlipQrData(
      crcValid: validateCrc(payload),
      bankCode: bankCode,
      transRef: transRef,
      rawFields: fields,
    );
  }

  static List<TlvField> _flatten(List<TlvField> fields) {
    final out = <TlvField>[];
    for (final f in fields) {
      out.add(f);
      if (f.children.isNotEmpty) out.addAll(_flatten(f.children));
    }
    return out;
  }
}
