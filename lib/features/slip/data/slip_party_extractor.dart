import '../../../core/constants/bank_codes.dart';

/// Sender / receiver names + bank codes recovered from a slip's **Thai** OCR
/// text. Bank fields are [BankCodes] codes (e.g. `'004'`), matching what
/// `account_flow.dart` resolves via `BankCodes.byCode`.
class SlipParties {
  const SlipParties({
    this.senderName,
    this.receiverName,
    this.senderBankCode,
    this.receiverBankCode,
  });

  final String? senderName;
  final String? receiverName;
  final String? senderBankCode;
  final String? receiverBankCode;

  bool get isEmpty =>
      senderName == null &&
      receiverName == null &&
      senderBankCode == null &&
      receiverBankCode == null;
}

/// Pure, plugin-free extraction of the two parties (who paid → who got paid)
/// from a Thai bank slip's OCR text. The on-device Latin OCR can't read Thai
/// names, so this works on the Tesseract (`tha`) pass.
///
/// Tesseract output on stylised slip fonts is noisy, so the heuristics anchor
/// on directional **labels** (`จาก`/`ไปยัง`/`ผู้โอน`/`ผู้รับเงิน`) and on Thai
/// **honorifics** (`นาย`/`นาง`/`น.ส.`) rather than exact character accuracy.
/// The QR sending-bank code (authoritative) is used to anchor the sender side.
class SlipPartyExtractor {
  const SlipPartyExtractor._();

  // Most specific first; `จาก` is generic so it comes last.
  static const _senderLabels = ['บัญชีผู้โอน', 'ผู้โอน', 'จากบัญชี', 'จาก'];
  static const _receiverLabels = [
    'บัญชีผู้รับ',
    'ผู้รับเงิน',
    'ผู้รับ',
    'เข้าบัญชี',
    'ไปยัง',
    'ไปที่',
  ];

  static const _honorifics = [
    'นางสาว',
    'น.ส.',
    'นาย',
    'นาง',
    'ด.ช.',
    'ด.ญ.',
    'บริษัท',
    'บจก.',
    'บมจ.',
    'หจก.',
    'ร้าน',
  ];

  /// Thai tokens that mark a non-name line (amounts, fees, refs, headers).
  static const _stopWords = [
    'จำนวน',
    'ยอดเงิน',
    'ค่าธรรมเนียม',
    'รหัส',
    'เลขที่',
    'อ้างอิง',
    'วันที่',
    'เวลา',
    'คงเหลือ',
    'บาท',
    'สแกน',
    'ตรวจสอบ',
    'สลิป',
    'โอนเงิน',
    'สำเร็จ',
    'รายการ',
    'พร้อมเพย์',
  ];

  // Masked account fragments, e.g. xxx-x-x1234-x, x-xxxx-xxxxx-x, ***1234.
  static final _accountMask = RegExp(r'[xX\*]+[\dxX\*\- ]{2,}');
  // The Thai Unicode block (U+0E00–U+0E7F).
  static final _thai = RegExp('[฀-๿]');

  static SlipParties extract({
    required String thaiText,
    String? qrSenderBankCode,
  }) {
    final lines = thaiText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty && qrSenderBankCode == null) return const SlipParties();

    final senderIdx = _labelIndex(lines, _senderLabels);
    final receiverIdx = _labelIndex(lines, _receiverLabels);

    String? senderName;
    String? receiverName;
    if (senderIdx != null) {
      final end = _boundaryAfter(senderIdx, receiverIdx);
      senderName = _nameNear(lines, senderIdx, end);
    }
    if (receiverIdx != null) {
      final end = _boundaryAfter(receiverIdx, senderIdx);
      receiverName = _nameNear(lines, receiverIdx, end);
    }

    // No usable labels: take the first two honorific-led names, top → bottom
    // (the common K PLUS / SCB layout lists sender first, receiver below).
    if (senderName == null && receiverName == null) {
      final names = lines.where(_looksLikeName).map(_clean).toList();
      if (names.length >= 2) {
        senderName = names[0];
        receiverName = names[1];
      }
    }

    // ---- Banks --------------------------------------------------------------
    String? senderBankCode = qrSenderBankCode;
    String? receiverBankCode;
    if (senderIdx != null || receiverIdx != null) {
      final senderRegion = _region(lines, senderIdx, receiverIdx);
      final receiverRegion = _region(lines, receiverIdx, senderIdx);
      senderBankCode ??= BankCodes.detectFromText(senderRegion)?.code;
      receiverBankCode = BankCodes.detectFromText(receiverRegion)?.code;
    } else {
      final detected = BankCodes.detectAllFromText(thaiText);
      final banks = detected.map((b) => b.code).toList();
      senderBankCode ??= banks.isNotEmpty ? banks.first : null;
      for (final code in banks) {
        if (code != senderBankCode) {
          receiverBankCode = code;
          break;
        }
      }
    }

    return SlipParties(
      senderName: senderName,
      receiverName: receiverName,
      senderBankCode: senderBankCode,
      receiverBankCode: receiverBankCode,
    );
  }

  /// Index of the first line containing any of [labels], or null.
  static int? _labelIndex(List<String> lines, List<String> labels) {
    for (var i = 0; i < lines.length; i++) {
      if (labels.any(lines[i].contains)) return i;
    }
    return null;
  }

  /// Where a region anchored at [idx] should stop: the other label's line if it
  /// comes after, otherwise a short window.
  static int _boundaryAfter(int idx, int? other) =>
      (other != null && other > idx) ? other : idx + 5;

  /// The first plausible name at/after the label line [idx], up to [end].
  static String? _nameNear(List<String> lines, int idx, int end) {
    final inline = _afterLabel(lines[idx]);
    if (inline != null && _looksLikeName(inline)) return _clean(inline);
    for (var i = idx + 1; i < end && i < lines.length; i++) {
      if (_looksLikeName(lines[i])) return _clean(lines[i]);
    }
    return null;
  }

  /// Text following the first label found on [line], or null when the line is
  /// just the label (the name is on a following line).
  static String? _afterLabel(String line) {
    for (final lbl in [..._senderLabels, ..._receiverLabels]) {
      final i = line.indexOf(lbl);
      if (i >= 0) {
        final rest = line
            .substring(i + lbl.length)
            .replaceFirst(RegExp(r'^[\s:：\-]+'), '')
            .trim();
        return rest.isEmpty ? null : rest;
      }
    }
    return null;
  }

  /// The joined text between [start] (inclusive) and [end] (exclusive). When
  /// [end] is null or not after [start], a short window from [start] is used.
  static String _region(List<String> lines, int? start, int? end) {
    if (start == null) return '';
    final stop = (end != null && end > start) ? end : (start + 5);
    final clamped = stop < lines.length ? stop : lines.length;
    return lines.sublist(start, clamped).join('\n');
  }

  /// A line is a plausible party name when it carries Thai letters, isn't just
  /// a label, isn't a bank name (unless it also has an honorific), isn't an
  /// amount/ref line, and isn't mostly digits.
  static bool _looksLikeName(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return false;
    final cleaned = _clean(s);
    if (cleaned.length < 2 || !_thai.hasMatch(cleaned)) return false;

    final hasHonorific = _honorifics.any(s.contains);
    if (hasHonorific) return true;

    if (_isLabelOnly(s)) return false;
    if (BankCodes.detectFromText(s) != null) return false;
    if (_stopWords.any(s.contains)) return false;
    final digits = RegExp(r'\d').allMatches(cleaned).length;
    if (digits * 3 > cleaned.length) return false;
    return true;
  }

  static bool _isLabelOnly(String s) => _clean(s).isEmpty;

  /// Strip a leading label, masked account numbers and separators; collapse
  /// whitespace.
  static String _clean(String s) {
    var out = s;
    for (final lbl in [..._senderLabels, ..._receiverLabels]) {
      if (out.startsWith(lbl)) {
        out = out.substring(lbl.length);
        break;
      }
    }
    out = out.replaceAll(_accountMask, ' ');
    out = out.replaceAll(RegExp(r'[:：]'), ' ');
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }
}
