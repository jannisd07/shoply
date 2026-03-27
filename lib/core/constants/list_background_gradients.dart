import 'package:flutter/material.dart';

/// Verfügbare Hintergründe für Listen - Premium Quality Gradients
class ListBackgroundGradients {
  // Map von Gradient-ID zu Namen
  static final Map<String, String> gradientNames = {
    'gradient_1': 'Northern Lights',
    'gradient_2': 'Sunset Paradise',
    'gradient_3': 'Ocean Deep',
    'gradient_4': 'Tropical Forest',
    'gradient_5': 'Pink Dreams',
    'gradient_6': 'Desert Sand',
    'gradient_7': 'Purple Haze',
    'gradient_8': 'Mint Fresh',
    'gradient_9': 'Autumn Vibes',
    'gradient_10': 'Lavender Sky',
    'gradient_11': 'Midnight City',
    'gradient_12': 'Cherry Blossom',
    'gradient_13': 'Electric Violet',
    'gradient_14': 'Golden Hour',
    'gradient_15': 'Cyber Punk',
  };

  // Map von Gradient-ID zu Gradient
  static final Map<String, LinearGradient> gradients = {
    // 1. Northern Lights - Aurora Borealis
    'gradient_1': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF00C6FF),
        Color(0xFF0072FF),
        Color(0xFF8E2DE2),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 2. Sunset Paradise - Warmer Sonnenuntergang
    'gradient_2': const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFF6B6B),
        Color(0xFFFFE66D),
        Color(0xFFFF8E53),
      ],
      stops: [0.0, 0.4, 1.0],
    ),
    
    // 3. Ocean Deep - Tiefes Meer
    'gradient_3': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF2E3192),
        Color(0xFF1BFFFF),
        Color(0xFF00B4DB),
      ],
      stops: [0.0, 0.6, 1.0],
    ),
    
    // 4. Tropical Forest - Tropischer Regenwald
    'gradient_4': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0B486B),
        Color(0xFF3B8686),
        Color(0xFF79BD9A),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 5. Pink Dreams - Rosa Träume
    'gradient_5': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFF6FD8),
        Color(0xFF3813C2),
        Color(0xFFE03368),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 6. Desert Sand - Wüstensand
    'gradient_6': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFD4A574),
        Color(0xFFEDC9AF),
        Color(0xFFF4DFB6),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 7. Purple Haze - Lila Nebel
    'gradient_7': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF667EEA),
        Color(0xFF764BA2),
        Color(0xFFF093FB),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 8. Mint Fresh - Frische Minze
    'gradient_8': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF2AF598),
        Color(0xFF009EFD),
        Color(0xFF6DD5FA),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 9. Autumn Vibes - Herbststimmung
    'gradient_9': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFDA4453),
        Color(0xFFE9765B),
        Color(0xFFF7B733),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 10. Lavender Sky - Lavendelhimmel
    'gradient_10': const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFDDD6F3),
        Color(0xFFFAEAA0),
        Color(0xFFFFD3A5),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 11. Midnight City - Mitternachtsstadt
    'gradient_11': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF232526),
        Color(0xFF414345),
        Color(0xFF2C3E50),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 12. Cherry Blossom - Kirschblüte
    'gradient_12': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFBD3E9),
        Color(0xFFBB377D),
        Color(0xFFFFB7B2),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 13. Electric Violet - Elektrisches Violett
    'gradient_13': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF4A00E0),
        Color(0xFF8E2DE2),
        Color(0xFFFA6FFF),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 14. Golden Hour - Goldene Stunde
    'gradient_14': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFD89B),
        Color(0xFFFF9A56),
        Color(0xFFFDA085),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
    
    // 15. Cyber Punk - Neon Zukunft
    'gradient_15': const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFF0099),
        Color(0xFF493240),
        Color(0xFF00FFFF),
      ],
      stops: [0.0, 0.5, 1.0],
    ),
  };

  /// Hole Gradient für eine ID oder null wenn nicht gefunden
  static LinearGradient? getGradient(String? gradientId) {
    if (gradientId == null) return null;
    return gradients[gradientId];
  }

  /// Hole Namen für Gradient-ID
  static String? getGradientName(String? gradientId) {
    if (gradientId == null) return null;
    return gradientNames[gradientId];
  }
}
