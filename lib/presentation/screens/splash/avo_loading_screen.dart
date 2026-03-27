import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AvoLoadingScreen extends StatefulWidget {
  const AvoLoadingScreen({super.key});

  @override
  State<AvoLoadingScreen> createState() => _AvoLoadingScreenState();
}

class _AvoLoadingScreenState extends State<AvoLoadingScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/avo/avi_loading.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: _initialized
            ? SizedBox(
                width: 80,
                height: 80,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
