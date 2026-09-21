import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../settings/reasoning_settings.dart';
import '../../domain/reasoning_state.dart';
import '../chat_rich_content.dart';

/// Collapsible "Thinking / Thought for Ns" block.
///
/// While reasoning streams the header shows an animated indicator with the
/// current phase and a live elapsed timer; once reasoning completes the header
/// becomes a one-line summary and the body collapses (unless the user pinned it
/// open). The body renders through [ChatRichContent] so reasoning markdown and
/// code fences display correctly.
class ReasoningBlock extends StatefulWidget {
  const ReasoningBlock({
    super.key,
    required this.reasoning,
    this.isStreaming = false,
    this.displayMode = ReasoningDisplayMode.collapsed,
    this.keepExpandedOnComplete = false,
  });

  final ReasoningState reasoning;

  /// True while the assistant turn is still running.
  final bool isStreaming;

  final ReasoningDisplayMode displayMode;

  /// When true the block stays open after reasoning finishes.
  final bool keepExpandedOnComplete;

  @override
  State<ReasoningBlock> createState() => _ReasoningBlockState();
}

class _ReasoningBlockState extends State<ReasoningBlock> {
  static const Duration _autoCollapseDelay = Duration(milliseconds: 1400);
  static const Duration _tickInterval = Duration(seconds: 1);

  bool _expanded = false;
  Timer? _collapseTimer;
  Timer? _tickTimer;
  bool _autoCollapsed = false;

  bool get _isStreaming =>
      widget.isStreaming ||
      widget.reasoning.status == ReasoningStatus.streaming;

  @override
  void initState() {
    super.initState();
    _syncInitialExpansion();
    _syncTickTimer();
  }

  @override
  void didUpdateWidget(covariant ReasoningBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasStreaming =
        oldWidget.isStreaming ||
        oldWidget.reasoning.status == ReasoningStatus.streaming;
    if (!wasStreaming && _isStreaming) {
      _autoCollapsed = false;
      _collapseTimer?.cancel();
      if (!_expanded && widget.displayMode != ReasoningDisplayMode.hidden) {
        setState(() => _expanded = true);
      }
    } else if (wasStreaming && !_isStreaming) {
      _scheduleAutoCollapse();
    }
    _syncTickTimer();
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _syncInitialExpansion() {
    switch (widget.displayMode) {
      case ReasoningDisplayMode.always:
        _expanded = true;
      case ReasoningDisplayMode.hidden:
        _expanded = false;
      case ReasoningDisplayMode.collapsed:
        _expanded = _isStreaming;
    }
  }

  /// Keeps the elapsed label moving even when no new deltas arrive.
  void _syncTickTimer() {
    if (_isStreaming) {
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

  void _scheduleAutoCollapse() {
    if (widget.displayMode == ReasoningDisplayMode.always ||
        widget.keepExpandedOnComplete ||
        _autoCollapsed) {
      return;
    }
    _collapseTimer?.cancel();
    _collapseTimer = Timer(_autoCollapseDelay, () {
      _autoCollapsed = true;
      if (mounted) {
        setState(() => _expanded = false);
      }
    });
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _autoCollapsed = true;
        _collapseTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.displayMode == ReasoningDisplayMode.hidden) {
      return const SizedBox.shrink();
    }
    final reasoning = widget.reasoning;
    final hasContent = reasoning.hasContent;
    if (!hasContent && !_isStreaming) {
      return const SizedBox.shrink();
    }

    final accent = reasoning.status == ReasoningStatus.failed
        ? AppColors.error
        : AppColors.tealBright;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: _expanded ? Radius.zero : const Radius.circular(12),
            ),
            onTap: hasContent ? _toggleExpanded : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              child: Row(
                children: [
                  Expanded(child: _buildHeader(accent)),
                  if (hasContent) ...[
                    if (reasoning.segmentCount > 1)
                      StatusPill(
                        label: '${reasoning.segmentCount} parts',
                        color: AppColors.textMuted,
                        dense: true,
                      ),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded && hasContent)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _isStreaming
                  ? _StreamingReasoningBody(text: reasoning.text, accent: accent)
                  : ChatRichContent(data: reasoning.text, streamingMode: false),
            ),
          if (reasoning.status == ReasoningStatus.failed &&
              (reasoning.error?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                reasoning.error!,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.error,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    final reasoning = widget.reasoning;
    if (_isStreaming) {
      final phaseLabel = reasoning.phaseLabel;
      final elapsed = formatDurationShort(reasoning.durationMs);
      return Row(
        children: [
          Expanded(
            child: ThinkingAnimation(
              label: phaseLabel == null || phaseLabel.isEmpty
                  ? 'Thinking…'
                  : '$phaseLabel…',
              compact: true,
              accentColor: accent,
              labelStyle: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (elapsed.isNotEmpty)
            Text(
              elapsed,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                fontSize: 10.6,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          reasoning.status == ReasoningStatus.failed
              ? Icons.error_outline_rounded
              : Icons.psychology_alt_rounded,
          size: 13,
          color: accent,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            buildReasoningSummary(reasoning),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// `Thought for 12s · ~430 tokens`, or just `Thought` when unknown.
String buildReasoningSummary(ReasoningState reasoning) {
  final buffer = StringBuffer();
  final durationMs = reasoning.durationMs;
  if (durationMs != null && durationMs > 0) {
    buffer.write('Thought for ${formatDurationShort(durationMs)}');
  } else {
    buffer.write('Thought');
  }
  final tokens = reasoning.reasoningTokens;
  if (tokens != null && tokens > 0) {
    buffer
      ..write(' · ~')
      ..write(formatCompactTokens(tokens))
      ..write(' tokens');
  }
  return buffer.toString();
}

class _StreamingReasoningBody extends StatelessWidget {
  const _StreamingReasoningBody({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySecondary.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12.4,
              height: 1.42,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: PulsingDots(color: accent, dotSize: 3.4, spacing: 2.6),
        ),
      ],
    );
  }
}
