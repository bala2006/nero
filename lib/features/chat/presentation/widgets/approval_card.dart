import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../runtime/application/approval_gate.dart';
import '../../../runtime/domain/agent_policy.dart';

/// Inline prompt shown while the agent is blocked on a tool call.
///
/// The run genuinely waits here: approving resumes the exact call that was
/// intercepted, rejecting hands the model a refusal it has to work around.
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({
    super.key,
    required this.approval,
    required this.onApprove,
    required this.onReject,
  });

  final PendingApproval approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  Color get _accent => switch (approval.risk) {
    ToolRiskLevel.readOnly => AppColors.tealBright,
    ToolRiskLevel.write => AppColors.amber,
    ToolRiskLevel.destructive => AppColors.error,
    ToolRiskLevel.unknown => AppColors.orange,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.gpp_maybe_rounded, size: 17, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Allow ${approval.title}?',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill(
                label: approval.risk.label,
                color: _accent,
                dense: true,
              ),
            ],
          ),
          if (approval.rationale != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              approval.rationale!,
              style: AppTextStyles.bodySecondary.copyWith(
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  approval.toolName,
                  style: AppTextStyles.codeMono(
                    color: AppColors.textSecondary,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  approval.argumentsSummary,
                  style: AppTextStyles.codeMono(
                    color: AppColors.textMuted,
                    fontSize: 10.4,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.play_arrow_rounded, size: 17),
                  label: const Text('Allow once'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label: const Text('Deny'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderSoft),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
