import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Orbiting-particle "thinking" indicator with a shimmering label.
///
/// Moved out of `features/chat/presentation/ai_thinking_animation.dart` and
/// generalised: the label, size and colours are now parameters so the reasoning
/// block and the composer strip can reuse it.
class ThinkingAnimation extends StatefulWidget {
  const ThinkingAnimation({
    super.key,
    this.label = 'Thinking...',
    this.labelStyle,
    this.particleCount = 3,
    this.orbSize = 24,
    this.particleRadius = 8,
    this.accentColor = AppColors.tealBright,
    this.showLabel = true,
    this.compact = false,
  });

  final String label;
  final TextStyle? labelStyle;
  final int particleCount;
  final double orbSize;
  final double particleRadius;
  final Color accentColor;
  final bool showLabel;
  final bool compact;

  @override
  State<ThinkingAnimation> createState() => _ThinkingAnimationState();
}

class _ThinkingAnimationState extends State<ThinkingAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  late final AnimationController _shimmerController;
  late final List<_ParticleData> _particles;
  late final List<Widget> _particleWidgets;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _particles = List<_ParticleData>.generate(widget.particleCount, (index) {
      final angle = (index * (360 / widget.particleCount)) * math.pi / 180;
      return _ParticleData(angle: angle, radius: widget.particleRadius);
    });
    _particleWidgets = List<Widget>.generate(widget.particleCount, (index) {
      final particle = _particles[index];
      final color = Color.lerp(
        AppColors.textMuted,
        widget.accentColor,
        index / widget.particleCount,
      )!;
      return Transform.translate(
        offset: Offset(
          math.cos(particle.angle) * particle.radius,
          math.sin(particle.angle) * particle.radius,
        ),
        child: _ParticleWidget(
          pulseController: _pulseController,
          color: color,
          size: widget.compact ? 3 : 4,
        ),
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbSize = widget.compact ? widget.orbSize * 0.75 : widget.orbSize;
    final coreSize = widget.compact ? 6.0 : 8.0;
    final labelStyle =
        widget.labelStyle ??
        AppTextStyles.body.copyWith(
          color: AppColors.textSecondary,
          fontSize: widget.compact ? 12 : 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        );

    return SizedBox(
      height: orbSize + (widget.compact ? 4 : 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: orbSize,
            height: orbSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, _) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi,
                      child: Stack(
                        alignment: Alignment.center,
                        children: _particleWidgets,
                      ),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final scale = 0.9 + (_pulseController.value * 0.15);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: coreSize,
                        height: coreSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.accentColor,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (widget.showLabel) ...[
            SizedBox(width: widget.compact ? 6 : 8),
            AnimatedBuilder(
              animation: Listenable.merge([
                _pulseController,
                _shimmerController,
              ]),
              builder: (context, _) {
                final opacity = 0.7 + (_pulseController.value * 0.3);
                return Opacity(
                  opacity: opacity,
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      final shimmerPosition =
                          _shimmerController.value * 3 - 1;
                      return LinearGradient(
                        begin: Alignment(shimmerPosition - 0.5, 0),
                        end: Alignment(shimmerPosition + 0.5, 0),
                        colors: [
                          labelStyle.color ?? AppColors.textMuted,
                          AppColors.textPrimary,
                          labelStyle.color ?? AppColors.textMuted,
                        ],
                      ).createShader(bounds);
                    },
                    child: Text(widget.label, style: labelStyle),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ParticleData {
  const _ParticleData({required this.angle, required this.radius});

  final double angle;
  final double radius;
}

class _ParticleWidget extends StatelessWidget {
  const _ParticleWidget({
    required this.pulseController,
    required this.color,
    required this.size,
  });

  final AnimationController pulseController;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, _) {
        final scale = 0.8 + (pulseController.value * 0.3);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        );
      },
    );
  }
}

/// Self-sizing horizontal divider used between tool rows in activity cards.
class TimelineConnector extends StatelessWidget {
  const TimelineConnector({
    super.key,
    required this.color,
    this.height = 8,
  });

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 1.4,
        height: height,
        color: color.withValues(alpha: 0.28),
      ),
    );
  }
}
