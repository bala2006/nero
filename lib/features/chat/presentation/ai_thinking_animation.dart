import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AIThinkingAnimation extends StatefulWidget {
  const AIThinkingAnimation({super.key});

  @override
  State<AIThinkingAnimation> createState() => _AIThinkingAnimationState();
}

class _AIThinkingAnimationState extends State<AIThinkingAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  late final AnimationController _shimmerController;

  static const _particleCount = 3;
  static const _particleRadius = 8.0;

  static final List<_ParticleData> _particles = List.generate(_particleCount, (index) {
    final angle = (index * 120) * math.pi / 180;
    return _ParticleData(angle: angle, radius: _particleRadius);
  });

  static final _shimmerGradientColors = [
    AppColors.textMuted,
    AppColors.textPrimary,
    AppColors.textMuted,
  ];

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

    _particleWidgets = List.generate(_particleCount, (index) {
      final particle = _particles[index];
      final color = Color.lerp(
        AppColors.textMuted,
        AppColors.tealBright,
        index / _particleCount,
      )!;
      return Transform.translate(
        offset: Offset(
          math.cos(particle.angle) * particle.radius,
          math.sin(particle.angle) * particle.radius,
        ),
        child: _ParticleWidget(
          pulseController: _pulseController,
          color: color,
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
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
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
                  builder: (context, child) {
                    final scale = 0.9 + (_pulseController.value * 0.15);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.tealBright,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          AnimatedBuilder(
            animation: Listenable.merge([
              _pulseController,
              _shimmerController,
            ]),
            builder: (context, child) {
              final opacity = 0.7 + (_pulseController.value * 0.3);
              return Opacity(
                opacity: opacity,
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    final shimmerPosition = _shimmerController.value * 3 - 1;
                    return LinearGradient(
                      begin: Alignment(shimmerPosition - 0.5, 0),
                      end: Alignment(shimmerPosition + 0.5, 0),
                      colors: _shimmerGradientColors,
                    ).createShader(bounds);
                  },
                  child: const Text(
                    'Thinking...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              );
            },
          ),
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
  const _ParticleWidget({required this.pulseController, required this.color});
  final AnimationController pulseController;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final scale = 0.8 + (pulseController.value * 0.3);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        );
      },
    );
  }
}
