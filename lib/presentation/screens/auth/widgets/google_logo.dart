import 'package:flutter/material.dart';
import 'package:shoply/core/constants/paper_colors.dart';

/// Google "G" for the "Continue with Google" buttons, with an offline
/// fallback icon.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://www.google.com/favicon.ico',
      height: 18,
      width: 18,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.g_mobiledata,
        size: 22,
        color: PaperColors.creamInk,
      ),
    );
  }
}
