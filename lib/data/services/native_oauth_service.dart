import 'package:flutter/services.dart';

class NativeOAuthService {
  static const MethodChannel _channel = MethodChannel('com.shoply.oauth');
  static Function(String)? _onRedirectCallback;

  static Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onRedirect') {
      final url = call.arguments['url'] as String?;
      if (url != null && _onRedirectCallback != null) {
        _onRedirectCallback!(url);
      }
    }
  }

  static Future<void> showOAuthWindow({
    required String authUrl,
    required String redirectScheme,
    required Function(String) onRedirect,
  }) async {
    _onRedirectCallback = onRedirect;
    
    try {
      await _channel.invokeMethod('showOAuthWindow', {
        'authUrl': authUrl,
        'redirectScheme': redirectScheme,
      });
    } catch (e) {
      rethrow;
    }
  }
}
