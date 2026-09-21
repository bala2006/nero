import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-bleed dark backdrop with soft radial glow orbs.
///
/// Previously duplicated as `_PremiumBackdrop` in the chat screen and
/// `_NeroBackdrop` in the settings screen; both now use this widget.
class NeroBackdrop extends StatelessWidget {
  const NeroBackdrop({
    super.key,
    this.showPrimaryOrb = true,
    this.showSecondaryOrb = true,
  });

  final bool showPrimaryOrb;
  final bool showSecondaryOrb;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AppColors.backgroundBackdrop),
        if (showPrimaryOrb)
          const Positioned(
            top: -90,
            right: -70,
            child: GlowOrb(color: AppColors.backdropGlowPrimary),
          ),
        if (showSecondaryOrb)
          const Positioned(
            bottom: -120,
            left: -90,
            child: GlowOrb(color: AppColors.backdropGlowSecondary),
          ),
      ],
    );
  }
}

/// A soft radial glow used to add depth to the backdrop.
class GlowOrb extends StatelessWidget {
  const GlowOrb({
    super.key,
    required this.color,
    this.size = 220,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}
