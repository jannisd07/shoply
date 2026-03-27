import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:shoply/core/constants/app_colors.dart';

class OAuthWebViewDialog extends StatefulWidget {
  final String authUrl;
  final String redirectScheme;
  final Function(String) onRedirect;

  const OAuthWebViewDialog({
    super.key,
    required this.authUrl,
    required this.redirectScheme,
    required this.onRedirect,
  });

  @override
  State<OAuthWebViewDialog> createState() => _OAuthWebViewDialogState();
}

class _OAuthWebViewDialogState extends State<OAuthWebViewDialog> {
  @override
  void initState() {
    super.initState();
    // Only initialize if webview is supported on this platform
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
      // WebView initialization would go here for supported platforms
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if WebView is supported on this platform
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 600,
          height: 700,
          decoration: BoxDecoration(
            color: AppColors.lightCardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // WebView placeholder for unsupported platforms
              Expanded(
                child: Container(
                  color: AppColors.lightCardBackground,
                  child: const Center(
                    child: Text(
                      'WebView not supported on this platform.\nPlease use email/password sign-in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // For unsupported platforms, show a message
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 400,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.lightCardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Text(
              'OAuth not supported on this platform.\nPlease use email/password sign-in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }
  }
}
