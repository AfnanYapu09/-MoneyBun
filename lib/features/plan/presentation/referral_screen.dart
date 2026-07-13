import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/referral_service.dart';
import '../domain/plan.dart';

/// แพลนสมาชิก → ชวนเพื่อน: my referral code (copy/share) and the redeem box
/// for a friend's code. Both sides of a redemption get Ultra for the month.
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final _codeField = TextEditingController();
  String? _myCode;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _publishCode();
  }

  @override
  void dispose() {
    _codeField.dispose();
    super.dispose();
  }

  /// Publish (or re-fetch) my referral code so friends can redeem it. Offline
  /// fallback: show the derived code — publishing retries next open.
  Future<void> _publishCode() async {
    final uid = ref.read(authServiceProvider)?.currentUser?.uid;
    if (uid == null) return;
    final referral = ref.read(referralServiceProvider);
    var code = ReferralService.codeForUid(uid);
    if (referral != null) {
      try {
        code = await referral.publishMyCode(uid);
      } catch (_) {}
    }
    if (mounted) setState(() => _myCode = code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = ref.watch(planProvider);

    return SubScreenScaffold(
      title: l10n.settingsReferral,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            l10n.planHowTo,
            style: AppTypography.body(size: 13.5, color: context.palette.ink2),
          ),
          const SizedBox(height: 14),
          _MyCodeCard(
            code: _myCode,
            onCopy: () {
              final code = _myCode;
              if (code == null) return;
              Clipboard.setData(ClipboardData(text: code));
              _snack(l10n.planCodeCopied);
            },
            onShare: () {
              final code = _myCode;
              if (code == null) return;
              SharePlus.instance.share(
                ShareParams(text: l10n.planShareMessage(code)),
              );
            },
          ),
          if (plan.isFree) ...[
            const SizedBox(height: 12),
            _RedeemBox(
              controller: _codeField,
              redeeming: _redeeming,
              onRedeem: _redeem,
            ),
          ],
          const SizedBox(height: 14),
          Center(
            child: Text(
              l10n.planUltraHint,
              textAlign: TextAlign.center,
              style:
                  AppTypography.body(size: 12.5, color: context.palette.ink3),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _redeem() async {
    if (_redeeming) return;
    final l10n = AppLocalizations.of(context);
    final uid = ref.read(authServiceProvider)?.currentUser?.uid;
    final referral = ref.read(referralServiceProvider);
    if (uid == null || referral == null) return;
    final repo = ref.read(settingsRepositoryProvider);
    setState(() => _redeeming = true);
    try {
      final month = Plan.monthKey(DateTime.now());
      final result = await referral.redeem(_codeField.text, uid, month);
      switch (result) {
        case RedeemResult.success:
          await repo.setProMonth(month);
          if (!mounted) return;
          _codeField.clear();
          _snack(l10n.planRedeemSuccess);
        case RedeemResult.ownCode:
          _snack(l10n.planRedeemOwnCode);
        case RedeemResult.notFound:
          _snack(l10n.planRedeemInvalid);
        case RedeemResult.failed:
          _snack(l10n.planRedeemFailed);
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }
}

/// My referral code on a terracotta wash card with copy + share actions.
class _MyCodeCard extends StatelessWidget {
  const _MyCodeCard({
    required this.code,
    required this.onCopy,
    required this.onShare,
  });

  final String? code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: context.palette.terraWash,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.planMyCode,
            style: AppTypography.heading(
              size: 14.5,
              weight: FontWeight.w500,
              color: context.palette.terraFg,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  code ?? '· · · · · ·',
                  style: AppTypography.heading(
                    size: 28,
                    weight: FontWeight.w600,
                    letterSpacing: 6,
                    color: context.palette.ink,
                  ),
                ),
              ),
              IconButton(
                onPressed: code == null ? null : onCopy,
                icon: Icon(
                  AppIcons.copy,
                  size: 20,
                  color: context.palette.terraFg,
                ),
              ),
              IconButton(
                onPressed: code == null ? null : onShare,
                icon: Icon(
                  AppIcons.share,
                  size: 20,
                  color: context.palette.terraFg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The "กรอกโค้ดเพื่อน" box: code field + redeem button.
class _RedeemBox extends StatelessWidget {
  const _RedeemBox({
    required this.controller,
    required this.redeeming,
    required this.onRedeem,
  });

  final TextEditingController controller;
  final bool redeeming;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.planEnterCode,
            style: AppTypography.heading(size: 14.5, weight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: AppTypography.heading(
              size: 18,
              weight: FontWeight.w600,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: l10n.planEnterCodeHint,
              counterText: '',
              hintStyle: AppTypography.body(
                size: 14,
                color: context.palette.ink3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: l10n.planRedeem,
            loading: redeeming,
            onPressed: onRedeem,
          ),
        ],
      ),
    );
  }
}
