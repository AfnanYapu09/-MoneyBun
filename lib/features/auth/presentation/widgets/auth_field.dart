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
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
    this.autofillHints,
  });

  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;

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
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.line),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 19, color: context.palette.ink3),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              obscureText: _hidden,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onSubmitted: widget.onSubmitted,
              autocorrect: false,
              enableSuggestions: !widget.obscure,
              autofillHints: widget.autofillHints,
              style: AppTypography.body(size: 15),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle:
                    AppTypography.body(size: 15, color: context.palette.ink3),
              ),
            ),
          ),
          if (widget.obscure)
            InkWell(
              onTap: () => setState(() => _hidden = !_hidden),
              child: Icon(_hidden ? AppIcons.eye : AppIcons.eyeOff,
                  size: 19, color: context.palette.ink3),
            ),
        ],
      ),
    );
  }
}
