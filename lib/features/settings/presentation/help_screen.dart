import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'น้องบันอ่านสลิปจากไหน?',
      'น้องบันอ่านรูปสลิปในแกลเลอรีของเครื่องอัตโนมัติ ดึงหน้าหลักลงเพื่อสแกนล่าสุด'
    ),
    (
      'ทำไมบางสลิปอ่านไม่ออก?',
      'OCR ในเครื่องอ่านตัวเลข/วันที่ได้ ส่วนชื่อผู้ส่ง/รับต้องเปิด API ตรวจสลิปออนไลน์'
    ),
    (
      'ข้อมูลของฉันปลอดภัยไหม?',
      'ข้อมูลเก็บในเครื่องเป็นหลัก จะซิงค์ขึ้นคลาวด์เมื่อคุณล็อกอินเท่านั้น'
    ),
    (
      'เปลี่ยนหมวดหมู่ของรายการได้ไหม?',
      'ได้ แตะที่รายการแล้วเลือกหมวดหมู่ / แท็กใหม่ได้ตลอด'
    ),
    ('ตั้งงบประมาณยังไง?', 'ไปที่ สถิติ → งบประมาณ แล้วกดเพิ่มงบรายหมวด'),
  ];

  @override
  Widget build(BuildContext context) {
    return SubScreenScaffold(
      title: 'ช่วยเหลือ',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'ค้นหาคำถามที่พบบ่อย',
              prefixIcon: const Icon(AppIcons.search, size: 20),
            ),
          ),
          const SizedBox(height: 18),
          Text('คำถามที่พบบ่อย',
              style: AppTypography.heading(size: 16, weight: FontWeight.w500)),
          const SizedBox(height: 8),
          for (final faq in _faqs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FaqTile(question: faq.$1, answer: faq.$2),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ContactCard(
                  icon: AppIcons.messageCircle,
                  label: 'แชทกับเรา',
                  background: AppColors.terra,
                  foreground: AppColors.reverse,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContactCard(
                  icon: AppIcons.mail,
                  label: 'อีเมลซัพพอร์ต',
                  background: AppColors.paper,
                  foreground: AppColors.ink,
                  bordered: true,
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
  const _FaqTile({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
    this.bordered = false,
  });
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
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
        ],
      ),
    );
  }
}
