import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  // Support contacts.
  static const _lineId = 'afnan9632';
  static const _email = 'afnanyapu09@gmail.com';

  /// Open [uri]; if no app can handle it, copy [copyText] to the clipboard so
  /// the user can still reach us.
  static Future<void> _open(
      BuildContext context, Uri uri, String copyText) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      await Clipboard.setData(ClipboardData(text: copyText));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('คัดลอกแล้ว: $copyText')),
        );
      }
    }
  }

  static const _faqs = [
    (
      AppIcons.scanLine,
      'น้องบันอ่านสลิปได้ยังไง?',
      'น้องบันอ่านรูปสลิปในแกลเลอรีของเครื่องอัตโนมัติ ดึงหน้าหลักลงเพื่อสแกนล่าสุด'
    ),
    (
      AppIcons.layoutGrid,
      'จัดการหมวดหมู่และแท็ก',
      'ไปที่ ตั้งค่า → จัดการหมวดหมู่ หรือ จัดการแท็ก เพื่อเพิ่ม แก้ไข หรือจัดเรียง'
    ),
    (
      AppIcons.wallet,
      'ตั้งงบประมาณรายเดือน',
      'ไปที่ สถิติ → งบประมาณ แล้วกดเพิ่มงบรายหมวด'
    ),
    (
      AppIcons.shieldCheck,
      'ความปลอดภัยของข้อมูล',
      'ข้อมูลเก็บในเครื่องเป็นหลัก จะซิงค์ขึ้นคลาวด์เมื่อคุณล็อกอินเท่านั้น'
    ),
    (
      AppIcons.refreshCw,
      'ซิงค์ข้อมูลข้ามอุปกรณ์',
      'ล็อกอินด้วยบัญชีเดียวกันบนอีกเครื่อง ข้อมูลจะซิงค์อัตโนมัติ'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: 'ช่วยเหลือ',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.search, size: 18, color: AppColors.ink3),
                const SizedBox(width: 10),
                Text('ค้นหาคำถามที่พบบ่อย',
                    style:
                        AppTypography.body(size: 14.5, color: AppColors.ink3)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('คำถามที่พบบ่อย',
              style: AppTypography.heading(size: 14, weight: FontWeight.w500)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _faqs.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _FaqTile(
                    icon: _faqs[i].$1,
                    question: _faqs[i].$2,
                    answer: _faqs[i].$3,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ContactCard(
                  icon: AppIcons.messageCircle,
                  label: 'แชทกับเรา',
                  sub: 'LINE: $_lineId',
                  background: AppColors.terra,
                  foreground: AppColors.reverse,
                  onTap: () => _open(
                    context,
                    Uri.parse('https://line.me/ti/p/~$_lineId'),
                    'LINE ID: $_lineId',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactCard(
                  icon: AppIcons.mail,
                  label: 'อีเมลซัพพอร์ต',
                  sub: _email,
                  background: AppColors.paper,
                  foreground: AppColors.ink,
                  bordered: true,
                  onTap: () => _open(
                    context,
                    Uri(
                      scheme: 'mailto',
                      path: _email,
                      queryParameters: const {
                        'subject': 'MoneyBun — สอบถาม/แจ้งปัญหา',
                      },
                    ),
                    _email,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile(
      {required this.icon, required this.question, required this.answer});
  final IconData icon;
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: IconChip(icon: icon, size: 34, radius: 11, iconSize: 17),
        title: Text(question, style: AppTypography.body(size: 14.5)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(answer,
                style: AppTypography.body(
                    size: 13.5, color: AppColors.ink2, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.sub,
    this.onTap,
    this.bordered = false,
  });
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: bordered ? Border.all(color: AppColors.line) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: foreground, size: 24),
            const SizedBox(height: 8),
            Text(label,
                style: AppTypography.heading(
                    size: 14, weight: FontWeight.w500, color: foreground)),
            if (sub != null) ...[
              const SizedBox(height: 3),
              Text(sub!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                      size: 11.5, color: foreground.withValues(alpha: 0.85))),
            ],
          ],
        ),
      ),
    );
  }
}
