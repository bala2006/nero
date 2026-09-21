import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Text with a moving highlight, used while a value is still streaming.
class ShimmerText extends StatefulWidget {
  const ShimmerText({
    super.key,
    required this.text,
    required this.style,
    this.highlightColor = AppColors.textPrimary,
    this.duration = const Duration(milliseconds: 1800),
    this.maxLines = 1,
  });

  final String text;
  final TextStyle style;
  final Color highlightColor;
  final Duration duration;
  final int maxLines;

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final position = _controller.value * 3 - 1;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(position - 0.5, 0),
              end: Alignment(position + 0.5, 0),
              colors: [
                widget.style.color ?? AppColors.textMuted,
                widget.highlightColor,
                widget.style.color ?? AppColors.textMuted,
              ],
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          ),
        );
      },
    );
  }
}

/// Three-dot pulsing indicator used for very compact "busy" affordances.
class PulsingDots extends StatefulWidget {
  const PulsingDots({
    super.key,
    this.color = AppColors.tealBright,
    this.dotSize = 4,
    this.spacing = 3,
    this.count = 3,
    this.duration = const Duration(milliseconds: 1000),
  });

  final Color color;
  final double dotSize;
  final double spacing;
  final int count;
  final Duration duration;

  @override
  State<PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < widget.count; index++) ...[
              if (index > 0) SizedBox(width: widget.spacing),
              _buildDot(index),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDot(int index) {
    final phase = (_controller.value - (index / widget.count)) % 1.0;
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    final scale = 0.65 + (wave * 0.5);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: widget.dotSize,
        height: widget.dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.45 + (wave * 0.55)),
        ),
      ),
    );
  }
}
