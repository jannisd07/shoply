import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:shoply/core/constants/app_colors.dart';

class TypingLoadingHeader extends StatefulWidget {
  const TypingLoadingHeader({super.key});

  @override
  State<TypingLoadingHeader> createState() => _TypingLoadingHeaderState();
}

class _TypingLoadingHeaderState extends State<TypingLoadingHeader>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  String _displayedText = '';
  bool _isTyping = true;
  int _charIndex = 0;
  late AnimationController _cursorController;
  Timer? _typingTimer;

  final List<String> _loadingTexts = [
    "Let's brainstorm",
    "Plan your meals",
    "Build your list",
    "Find best deals",
    "Check ingredients",
    "Match offers",
    "Sort your items",
    "Update recipes",
    "Organize groceries",
    "Check allergies",
  ];

  @override
  void initState() {
    super.initState();
    
    // Animation für den blinkenden Kreis
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _startTyping();
  }

  void _startTyping() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_isTyping) {
          // Text schreiben
          if (_charIndex < _loadingTexts[_currentIndex].length) {
            _displayedText = _loadingTexts[_currentIndex].substring(0, _charIndex + 1);
            _charIndex++;
            
            // Haptisches Feedback alle 3 Buchstaben
            if (_charIndex % 3 == 0) {
              HapticFeedback.lightImpact();
            }
          } else {
            // Text fertig, kurz warten
            timer.cancel();
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                _isTyping = false;
                _startTyping();
              }
            });
          }
        } else {
          // Text löschen
          if (_charIndex > 0) {
            _charIndex--;
            _displayedText = _loadingTexts[_currentIndex].substring(0, _charIndex);
          } else {
            // Zum nächsten Text wechseln
            timer.cancel();
            _currentIndex = (_currentIndex + 1) % _loadingTexts.length;
            _isTyping = true;
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _startTyping();
              }
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _cursorController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimary(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Geschriebener Text
        Text(
          _displayedText,
          style: TextStyle(
            color: textColor,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 12),
        // Kreis (Farbe passt sich an Theme an)
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: textColor,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
