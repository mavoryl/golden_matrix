import 'package:flutter/material.dart';

/// A skeleton loader with an infinite shimmer animation.
///
/// Without `freezeAnimations: true` in `matrixGolden`, the test would
/// hang on `pumpAndSettle` because the shimmer never finishes.
class ShimmerLoader extends StatefulWidget {
  const ShimmerLoader({super.key});

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlight = isDark ? Colors.grey.shade600 : Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            colors: [base, highlight, base],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(-1.0 + _controller.value * 2, 0),
            end: Alignment(1.0 + _controller.value * 2, 0),
          ).createShader(rect),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 200, height: 16, color: Colors.white),
                const SizedBox(height: 8),
                Container(width: 160, height: 12, color: Colors.white),
                const SizedBox(height: 8),
                Container(width: 180, height: 12, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }
}
