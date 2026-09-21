import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/reasoning_state.dart';

/// Live "what is happening right now" strip shown above the composer while the
/// agent is working.
///
/// This is the always-visible counterpart to [ReasoningBlock]: the block lives
/// in the transcript, the strip keeps the user oriented while the transcript
/// has not produced any answer text yet.
class ThinkingStrip extends StatefulWidget {
  const ThinkingStrip({
    super.key,
    required this.reasoning,
    this.isGenerating = false,
    this.statusText,
    this.onStop,
  });

  final ReasoningState reasoning;
  final bool isGenerating;

  /// Coarse status from the controller, e.g. "Streaming response".
  final String? statusText;

  final VoidCallback? onStop;

  @override
  State<ThinkingStrip> createState() => _ThinkingStripState();
}

class _ThinkingStripState extends State<ThinkingStrip> {
  static const Duration _tickInterval = Duration(seconds: 1);
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _syncTickTimer();
  }

  @override
  void didUpdateWidget(covariant ThinkingStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTickTimer();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _syncTickTimer() {
    if (widget.isGenerating) {
      _tickTimer ??= Timer.periodic(_tickInterval, (_) {
        if (mounted) {
          setState(() {});
        }
      });
      return;
    }
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isGenerating) {
      return const SizedBox.shrink();
    }
    final reasoning = widget.reasoning;
    final phaseLabel = reasoning.phaseLabel;
    final statusText = widget.statusText;
    final label = (phaseLabel != null && phaseLabel.isNotEmpty)
        ? '$phaseLabel…'
        : (statusText != null && statusText.isNotEmpty
              ? statusText
              : 'Working…');
    final elapsed = formatDurationShort(reasoning.durationMs);

    return Row(
      children: [
        Expanded(
          child: ThinkingAnimation(
            label: label,
            compact: true,
            labelStyle: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (elapsed.isNotEmpty) ...[
          MiniChip(text: elapsed, icon: Icons.timer_outlined),
          const SizedBox(width: 6),
        ],
        if (reasoning.reasoningTokens != null &&
            reasoning.reasoningTokens! > 0) ...[
          MiniChip(
            text: '~${formatCompactTokens(reasoning.reasoningTokens!)}',
            icon: Icons.psychology_alt_rounded,
            accent: AppColors.tealBright,
          ),
          const SizedBox(width: 6),
        ],
        if (widget.onStop != null) ...[
          HeadlessStopButton(onTap: widget.onStop!),
        ],
      ],
    );
  }
}

/// Tiny inline stop control used inside the thinking strip.
class HeadlessStopButton extends StatelessWidget {
  const HeadlessStopButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.red,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Stop',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.red,
          fontSize: 11.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
