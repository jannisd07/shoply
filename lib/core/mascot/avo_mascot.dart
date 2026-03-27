import 'package:flutter/material.dart';

/// Expression states for the Avo mascot.
/// Maps to the PNG image files in assets/avo/
enum AvoExpression {
  /// Default/neutral state - uses waving Avo (friendly default)
  neutral,
  
  /// Happy state - uses excited Avo
  happy,
  
  /// Confused state - uses thinking Avo
  confused,
  
  /// Success state - uses celebrating Avo
  success,
  
  /// Waving/greeting state - uses waving Avo (for login/welcome)
  waving,
  
  /// Thinking state - uses thinking Avo
  thinking,
  
  /// Excited state - uses excited Avo
  excited,
  
  /// Celebrating state - uses celebrating Avo (thumbs up)
  celebrating,
}

/// The name of our mascot
const String avoName = 'Avo';

/// PNG image paths for each expression
const Map<AvoExpression, String> _avoImages = {
  AvoExpression.neutral: 'assets/avo/avo_waving.png',
  AvoExpression.happy: 'assets/avo/avo_excited.png',
  AvoExpression.confused: 'assets/avo/avo_thinking.png',
  AvoExpression.success: 'assets/avo/avo_celebrating.png',
  AvoExpression.waving: 'assets/avo/avo_waving.png',
  AvoExpression.thinking: 'assets/avo/avo_thinking.png',
  AvoExpression.excited: 'assets/avo/avo_excited.png',
  AvoExpression.celebrating: 'assets/avo/avo_celebrating.png',
};

/// Fallback image path
const String _avoFallback = 'assets/avo/avo_waving.png';

/// Image-based avocado mascot widget.
/// Uses different PNG images based on expression for more personality!
class AvoMascot extends StatelessWidget {
  final double size;
  final AvoExpression expression;
  final bool animate;
  final String? message;
  final VoidCallback? onTap;
  
  const AvoMascot({
    super.key,
    this.size = 80,
    this.expression = AvoExpression.neutral,
    this.animate = true,
    this.message,
    this.onTap,
  });
  
  /// Get the image path for the current expression
  String get _imagePath => _avoImages[expression] ?? _avoFallback;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null) ...[
            _buildSpeechBubble(context),
            const SizedBox(height: 8),
          ],
          // Use PNG image based on expression
          Image.asset(
            _imagePath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            // Use gaplessPlayback to prevent flickering when rebuilding
            gaplessPlayback: true,
            // Error handling - fallback to waving image
            errorBuilder: (context, error, stackTrace) {
              debugPrint('⚠️ [AVO] Image not found: $_imagePath, using fallback');
              return Image.asset(
                _avoFallback,
                width: size,
                height: size,
                fit: BoxFit.contain,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechBubble(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(maxWidth: size * 2.5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5E5),
          width: 1,
        ),
      ),
      child: Text(
        message!,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Widget to show Avo with a speech bubble message.
class AvoWithMessage extends StatelessWidget {
  final String message;
  final AvoExpression expression;
  final double avoSize;
  
  const AvoWithMessage({
    super.key,
    required this.message,
    this.expression = AvoExpression.neutral,
    this.avoSize = 60,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AvoMascot(size: avoSize, expression: expression),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
