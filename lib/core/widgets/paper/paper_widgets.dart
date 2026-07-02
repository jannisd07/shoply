import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shoply/core/constants/paper_colors.dart';

/// Letter-spaced section label, e.g. "ANMELDEN".
class PaperKicker extends StatelessWidget {
  final String text;
  final Color color;

  const PaperKicker(this.text, {super.key, this.color = PaperColors.muted});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: PaperTextStyles.kicker(color: color));
  }
}

/// Full-width ink pill button with optional loading state.
class PaperPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const PaperPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: PaperColors.ink,
          foregroundColor: PaperColors.paper,
          disabledBackgroundColor: PaperColors.ink.withValues(alpha: 0.55),
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: loading
            ? const CupertinoActivityIndicator(
                radius: 10,
                color: PaperColors.paper,
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

/// Full-width outlined pill button. [strong] uses an ink border,
/// otherwise a soft hairline.
class PaperOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool strong;
  final bool loading;

  const PaperOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.strong = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = strong ? PaperColors.ink : PaperColors.creamInk;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(
            color: strong ? PaperColors.ink : PaperColors.hairline,
            width: strong ? 1.2 : 1,
          ),
          shape: const StadiumBorder(),
        ),
        child: loading
            ? CupertinoActivityIndicator(radius: 10, color: textColor)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Label-above underline text field in paper style.
class PaperUnderlineField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffix;
  final int? maxLength;
  final TextAlign textAlign;
  final TextStyle? style;

  const PaperUnderlineField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.suffix,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: PaperColors.muted)),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          maxLength: maxLength,
          textAlign: textAlign,
          cursorColor: PaperColors.terracotta,
          style: style ?? const TextStyle(fontSize: 16, color: PaperColors.ink),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: style?.fontSize ?? 16,
              letterSpacing: style?.letterSpacing,
              color: PaperColors.faint,
            ),
            counterText: '',
            contentPadding: const EdgeInsets.only(top: 8, bottom: 10),
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 24),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: PaperColors.hairline),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: PaperColors.ink, width: 1.5),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: PaperColors.danger),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: PaperColors.danger, width: 1.5),
            ),
            errorStyle: const TextStyle(fontSize: 12, color: PaperColors.danger),
          ),
        ),
      ],
    );
  }
}

/// Hairline divider row with a centered word, e.g. "oder".
class PaperOrDivider extends StatelessWidget {
  final String text;

  const PaperOrDivider(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: PaperColors.hairline, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: PaperColors.muted),
          ),
        ),
        const Expanded(child: Divider(color: PaperColors.hairline, height: 1)),
      ],
    );
  }
}
