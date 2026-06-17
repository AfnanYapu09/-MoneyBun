import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/constants/bank_codes.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/pixel_border.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../domain/entities/parsed_slip.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';

class SlipScanScreen extends ConsumerStatefulWidget {
  const SlipScanScreen({super.key});

  @override
  ConsumerState<SlipScanScreen> createState() => _SlipScanScreenState();
}

class _SlipScanScreenState extends ConsumerState<SlipScanScreen> {
  final _picker = ImagePicker();
  ParsedSlip? _result;
  bool _processing = false;
  bool _verifying = false;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 2200);
    if (file == null) return;
    setState(() => _processing = true);
    try {
      final slip = await ref.read(slipPipelineProvider).process(file.path);
      setState(() => _result = slip);
    } catch (_) {
      setState(() => _result = const ParsedSlip(source: SlipSource.ocr));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _verifyOnline(AppLocalizations l10n) async {
    final api = ref.read(slipVerifyApiProvider);
    if (api == null) {
      _snack('ต้องตั้งค่า Firebase + เปิดใช้ API ก่อน');
      return;
    }
    setState(() => _verifying = true);
    try {
      String? imageBase64;
      final path = _result?.imagePath;
      if (_result?.qrPayload == null && path != null) {
        imageBase64 = base64Encode(await File(path).readAsBytes());
      }
      final verified = await api.verify(
        payload: _result?.qrPayload,
        imageBase64: imageBase64,
      );
      setState(
          () => _result = verified.copyWith(imagePath: _result?.imagePath));
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider).languageCode;
    final apiEnabled = ref.watch(slipApiEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanSlip)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: l10n.takePhoto,
                    icon: Icons.photo_camera,
                    expand: true,
                    onPressed: () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PixelButton(
                    label: l10n.pickFromGallery,
                    icon: Icons.photo_library,
                    color: AppColors.gray600,
                    expand: true,
                    onPressed: () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _processing
                  ? _busy(l10n.scanning)
                  : _result == null
                      ? _intro(l10n)
                      : _resultView(l10n, locale, apiEnabled),
            ),
          ],
        ),
      ),
    );
  }

  Widget _busy(String text) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BunAvatar(size: 72, mood: BunMood.idle),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(text),
          ],
        ),
      );

  Widget _intro(AppLocalizations l10n) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BunAvatar(size: 96, mood: BunMood.happy),
            const SizedBox(height: 16),
            Text(l10n.scanSlip,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('ถ่ายรูปหรือเลือกสลิป แล้วน้องบันจะอ่านให้',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.gray500)),
          ],
        ),
      );

  Widget _resultView(AppLocalizations l10n, String locale, bool apiEnabled) {
    final r = _result!;
    final bank = BankCodes.byCode(r.bankCode);
    final low = !r.isHighConfidence && !r.verified;

    return ListView(
      children: [
        PixelBorder(
          color: r.verified ? AppColors.orangeLight : AppColors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(r.verified ? Icons.verified : Icons.receipt_long,
                      color: AppColors.bunOrange),
                  const SizedBox(width: 8),
                  Text(
                    r.verified ? l10n.slipDetected : l10n.slipDetected,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const Divider(height: 20),
              _row(l10n.amount,
                  r.amountCents == null ? '-' : Money.format(r.amountCents!)),
              _row(
                l10n.dateTime,
                r.occurredAt == null
                    ? '-'
                    : '${AppDate.formatDay(r.occurredAt!, locale: locale)} ${AppDate.formatTime(r.occurredAt!, locale: locale)}',
              ),
              _row('ธนาคาร', bank?.nameTh ?? r.bankCode ?? '-'),
              if (r.senderName != null) _row('ผู้ส่ง', r.senderName!),
              if (r.receiverName != null) _row('ผู้รับ', r.receiverName!),
              _row('Ref', r.transRef ?? '-'),
              const SizedBox(height: 8),
              _ConfidenceBar(confidence: r.verified ? 1 : r.confidence),
            ],
          ),
        ),
        if (low)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l10n.lowConfidence,
                style: const TextStyle(color: AppColors.expense, fontSize: 13)),
          ),
        const SizedBox(height: 16),
        if (apiEnabled && !r.verified)
          OutlinedButton.icon(
            onPressed: _verifying ? null : () => _verifyOnline(l10n),
            icon: _verifying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_done),
            label: Text(l10n.verifyOnline),
          ),
        const SizedBox(height: 12),
        PixelButton(
          label: l10n.useAnyway,
          expand: true,
          onPressed: () => context.pop(_result),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(label,
                  style:
                      const TextStyle(color: AppColors.gray500, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.6
        ? AppColors.income
        : (confidence >= 0.4 ? AppColors.bunOrange : AppColors.expense);
    return Row(
      children: [
        const Text('ความมั่นใจ ',
            style: TextStyle(fontSize: 12, color: AppColors.gray500)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: confidence.clamp(0.02, 1),
              minHeight: 8,
              backgroundColor: AppColors.gray100,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(confidence * 100).round()}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
