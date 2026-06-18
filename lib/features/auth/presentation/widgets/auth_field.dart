import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_icons.dart';

/// A 54px outlined input field with a leading icon and optional password eye.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.icon,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
  });

  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 19, color: AppColors.ink3),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              obscureText: _hidden,
              keyboardType: widget.keyboardType,
              style: AppTypography.body(size: 15),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: AppTypography.body(size: 15, color: AppColors.ink3),
              ),
            ),
          ),
          if (widget.obscure)
            InkWell(
              onTap: () => setState(() => _hidden = !_hidden),
              child: Icon(_hidden ? AppIcons.eye : AppIcons.eyeOff,
                  size: 19, color: AppColors.ink3),
            ),
        ],
      ),
    );
  }
}
