import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/skill_models.dart';
import '../domain/skill_registry.dart';

/// Browses the built-in agent skills: what they do, what they need, and the
/// exact step graph they run.
///
/// Read-only by design. A skill is selected by the request classifier during a
/// run, so there is nothing to toggle here — this screen exists so the
/// automation is inspectable instead of invisible.
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final Set<String> _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final skills = SkillRegistry.all;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const NeroBackdrop(),
          SafeArea(
            child: Column(
              children: <Widget>[
                const NeroTopBar(
                  title: 'Skills',
                  subtitle: 'Multi-step workflows the agent can run end to end',
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    itemCount: skills.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const InlineBanner(
                          message:
                              'Nero picks a skill automatically from how you '
                              'phrase the request. Each skill declares its own '
                              'quality gates, so a run cannot claim success '
                              'without passing them.',
                          tone: InlineBannerTone.info,
                        );
                      }
                      final skill = skills[index - 1];
                      return _buildSkillCard(skill);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _visibilityLabel(SkillVisibility visibility) {
    return switch (visibility) {
      SkillVisibility.hidden => 'Hidden',
      SkillVisibility.visible => 'Model-visible',
      SkillVisibility.preferred => 'Preferred',
    };
  }

  Widget _buildSkillCard(SkillDescriptor skill) {
    final expanded = _expanded.contains(skill.skillId);
    final steps = skill.subgraph.steps;

    return SectionCard(
      title: skill.displayName,
      subtitle: skill.purpose,
      trailing: StatusPill(
        label: _visibilityLabel(skill.visibility),
        color: skill.visibility == SkillVisibility.preferred
            ? AppColors.orange
            : AppColors.amber,
        dense: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              StatusPill(
                label: '${steps.length} steps',
                color: AppColors.tealBright,
                dense: true,
                icon: Icons.account_tree_outlined,
              ),
              StatusPill(
                label: skill.policy.sideEffectPolicy.name,
                color: AppColors.amber,
                dense: true,
              ),
              if (skill.policy.approvalRequired)
                const StatusPill(
                  label: 'Needs approval',
                  color: AppColors.error,
                  dense: true,
                  icon: Icons.gpp_maybe_outlined,
                ),
              if (skill.policy.requiresVerifier)
                const StatusPill(
                  label: 'Verified',
                  color: AppColors.tealBright,
                  dense: true,
                  icon: Icons.verified_outlined,
                ),
              if (skill.policy.requiresEvidence)
                const StatusPill(
                  label: 'Evidence required',
                  color: AppColors.amber,
                  dense: true,
                ),
              for (final requestKind in skill.requestKinds)
                StatusPill(
                  label: requestKind.name,
                  color: AppColors.textMuted,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Triggered by: '
            '${skill.requestKinds.map((kind) => kind.name).join(', ')}',
            style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
          ),
          if (skill.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              skill.tags.map((tag) => '#$tag').join('  '),
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                if (expanded) {
                  _expanded.remove(skill.skillId);
                } else {
                  _expanded.add(skill.skillId);
                }
              });
            },
            icon: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
            ),
            label: Text(
              expanded ? 'Hide the step graph' : 'Show the step graph',
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.orange,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: 10),
            for (var index = 0; index < steps.length; index += 1)
              _buildStep(skill, steps[index], index, steps.length),
            const SizedBox(height: 6),
            SectionCard(
              title: 'Quality gates',
              subtitle: 'Checked before the run may report success.',
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final check in skill.qualityGate.requiredChecks)
                    StatusPill(
                      label: check.replaceAll('_', ' '),
                      color: AppColors.tealBright,
                      dense: true,
                    ),
                ],
              ),
            ),
            if (skill.requiredCapabilityKeys.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Uses: ${skill.requiredCapabilityKeys.join(', ')}',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Budget: up to ${skill.policy.maxRetries} retries, '
              '${skill.policy.timeoutMilliseconds ~/ 1000}s timeout.',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep(
    SkillDescriptor skill,
    SkillStepDescriptor step,
    int index,
    int total,
  ) {
    final isEntry = step.id == skill.subgraph.entryStepId;
    final isTerminal = step.id == skill.subgraph.terminalStepId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: NeroTile(
        title: '${index + 1}. ${step.title}',
        subtitle: step.description,
        leading: Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceOverlay,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Text(
            '${index + 1}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10.4,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        dense: true,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        borderRadius: 12,
        trailing: StatusPill(
          label: isEntry
              ? 'start'
              : isTerminal
              ? 'end'
              : step.kind.name,
          color: isEntry || isTerminal
              ? AppColors.orange
              : AppColors.textMuted,
          dense: true,
        ),
      ),
    );
  }
}
