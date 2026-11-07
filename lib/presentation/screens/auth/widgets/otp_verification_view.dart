import 'package:flutter/material.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/paper/paper_widgets.dart';

/// "Check your inbox" step shared by signup (email verification) and login
/// (password reset): 6-digit code field, verify button and resend link.
class OtpVerificationView extends StatelessWidget {
  final String kicker;
  final String? email;
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;

  const OtpVerificationView({
    super.key,
    required this.kicker,
    required this.email,
    required this.controller,
    required this.loading,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        IconButton(
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          icon: const Icon(Icons.arrow_back, size: 22, color: PaperColors.ink),
          onPressed: onBack,
        ),
        const SizedBox(height: 20),
        PaperKicker(kicker),
        const SizedBox(height: 10),
        Text(context.tr('otp_headline'), style: PaperTextStyles.serif(27)),
        const SizedBox(height: 14),
        Text(
          context.tr('otp_sent_to', params: {'email': email ?? ''}),
          style: PaperTextStyles.body(color: PaperColors.muted),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr('otp_check_spam'),
          style: PaperTextStyles.body(size: 12, color: PaperColors.faint),
        ),
        const SizedBox(height: 34),
        PaperUnderlineField(
          controller: controller,
          label: context.tr('otp_code_label'),
          hint: '000000',
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PaperColors.ink,
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 30),
        PaperPrimaryButton(
          label: context.tr('otp_verify_button'),
          loading: loading,
          onPressed: onVerify,
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: loading ? null : onResend,
            child: Text.rich(
              TextSpan(
                text: '${context.tr('otp_not_received')} ',
                style: const TextStyle(fontSize: 13, color: PaperColors.muted),
                children: [
                  TextSpan(
                    text: context.tr('resend'),
                    style: const TextStyle(
                      color: PaperColors.terracotta,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
