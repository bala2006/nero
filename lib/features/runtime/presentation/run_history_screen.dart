import 'package:flutter/material.dart';

import '../../../app/run_replay_bus.dart';
import '../../../core/format/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../application/runtime_run_store.dart';
import '../domain/runtime_resume_snapshot.dart';
import '../domain/runtime_run.dart';
import '../domain/runtime_run_event.dart';
import '../domain/runtime_run_node.dart';

/// Browse every agent run Nero has executed, with its node graph, events and
/// resumability.
///
/// Runs were already being persisted by `RuntimeRunStore` during orchestration;
/// until this screen existed there was no way to see them.
class RunHistoryScreen extends StatefulWidget {
  const RunHistoryScreen({super.key});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  final RuntimeRunStore _store = RuntimeRunStore();

  bool _loading = true;
  String? _error;
  List<RuntimeRun> _runs = const <RuntimeRun>[];
  RuntimeRunStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final runs = await _store.listRuns(limit: 150);
      if (!mounted) {
        return;
      }
      setState(() {
        _runs = runs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not read run history: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _runs
        .where(
          (run) =>
              run.status != RuntimeRunStatus.completed &&
              run.status != RuntimeRunStatus.failed &&
              run.status != RuntimeRunStatus.cancelled,
        )
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const NeroBackdrop(),
          SafeArea(
            child: Column(
              children: <Widget>[
                NeroTopBar(
                  title: 'Runs',
                  subtitle: _runs.isEmpty
                      ? 'No runs recorded yet'
                      : '${_runs.length} recorded · $active still open',
                  onBackTap: () => Navigator.of(context).maybePop(),
                  actions: <Widget>[
                    HeaderIconButton(
                      icon: Icons.refresh_rounded,
                      semanticLabel: 'Reload runs',
                      onTap: _load,
                    ),
                  ],
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: InlineBanner(
          message: error,
          tone: InlineBannerTone.error,
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }
    if (_runs.isEmpty) {
      return const EmptyState(
        icon: Icons.timeline_rounded,
        title: 'No runs yet',
        message:
            'Each agent turn is recorded here with its phases, tool calls and '
            'artifacts, so you can see exactly what happened.',
      );
    }

    final filtered = _statusFilter == null
        ? _runs
        : _runs.where((run) => run.status == _statusFilter).toList(
            growable: false,
          );

    return Column(
      children: <Widget>[
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: <Widget>[
              NeroActionChip(
                label: 'All',
                icon: Icons.select_all_rounded,
                selected: _statusFilter == null,
                accentColor: AppColors.orange,
                onTap: () => setState(() => _statusFilter = null),
              ),
              for (final status in RuntimeRunStatus.values) ...<Widget>[
                const SizedBox(width: 6),
                NeroActionChip(
                  label: _statusLabel(status),
                  selected: _statusFilter == status,
                  accentColor: AppColors.orange,
                  onTap: () => setState(() => _statusFilter = status),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'No runs with that status',
                  compact: true,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildRunCard(filtered[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildRunCard(RuntimeRun run) {
    final color = _statusColor(run.status);
    return SectionCard(
      title: run.title.isEmpty ? run.kind.name : run.title,
      subtitle: '${run.kind.name} · ${formatRelativeTime(run.updatedAtEpochMs)}'
          '${run.conversationId == null ? '' : ' · ${run.conversationId}'}',
      trailing: StatusPill(
        label: _statusLabel(run.status),
        color: color,
        dense: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (run.error != null && run.error!.isNotEmpty) ...<Widget>[
            InlineBanner(
              message: run.error!,
              tone: InlineBannerTone.error,
            ),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              if (run.capabilityKey != null)
                StatusPill(
                  label: run.capabilityKey!,
                  color: AppColors.amber,
                  dense: true,
                ),
              if (run.createdAtEpochMs > 0)
                StatusPill(
                  label: formatDateTime(run.createdAtEpochMs),
                  color: AppColors.textMuted,
                  dense: true,
                ),
              if (run.completedAtEpochMs != null &&
                  run.createdAtEpochMs > 0 &&
                  run.completedAtEpochMs! > run.createdAtEpochMs)
                StatusPill(
                  label: formatDurationMs(
                    run.completedAtEpochMs! - run.createdAtEpochMs,
                  ),
                  color: AppColors.tealBright,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: () => _openRunDetail(run),
                icon: const Icon(Icons.account_tree_outlined, size: 16),
                label: const Text(
                  'Open timeline',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              if (_replayPromptOf(run) != null) ...<Widget>[
                const SizedBox(width: 14),
                TextButton.icon(
                  onPressed: () => _replayRun(run),
                  icon: const Icon(Icons.replay_rounded, size: 15),
                  label: const Text(
                    'Run again',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.tealBright,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// The original prompt behind a conversation run, when it was recorded.
  String? _replayPromptOf(RuntimeRun run) {
    final prompt = run.request['prompt']?.toString();
    if (prompt == null || prompt.trim().isEmpty) {
      return null;
    }
    return prompt.trim();
  }

  /// Puts the run's prompt back into the composer and returns to the chat.
  void _replayRun(RuntimeRun run) {
    final prompt = _replayPromptOf(run);
    if (prompt == null) {
      return;
    }
    RunReplayBus.instance.emit(prompt);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openRunDetail(RuntimeRun run) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _RunDetailScreen(store: _store, run: run)),
    );
    await _load();
  }

  String _statusLabel(RuntimeRunStatus status) {
    // Enum names are camelCase; make them readable without a second source of
    // truth that can drift from the persisted values.
    final name = status.name;
    final buffer = StringBuffer();
    for (var index = 0; index < name.length; index += 1) {
      final character = name[index];
      final isUpper =
          character == character.toUpperCase() && character != character.toLowerCase();
      if (isUpper && index > 0) {
        buffer.write(' ');
      }
      buffer.write(index == 0 ? character.toUpperCase() : character);
    }
    return buffer.toString();
  }

  Color _statusColor(RuntimeRunStatus status) {
    return switch (status) {
      RuntimeRunStatus.completed => AppColors.tealBright,
      RuntimeRunStatus.failed => AppColors.error,
      RuntimeRunStatus.cancelled => AppColors.textMuted,
      RuntimeRunStatus.blocked || RuntimeRunStatus.waitingUser =>
        AppColors.orange,
      _ => AppColors.amber,
    };
  }
}

/// One run's node graph, event log and resume state.
class _RunDetailScreen extends StatefulWidget {
  const _RunDetailScreen({required this.store, required this.run});

  final RuntimeRunStore store;
  final RuntimeRun run;

  @override
  State<_RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends State<_RunDetailScreen> {
  bool _loading = true;
  List<RuntimeRunNode> _nodes = const <RuntimeRunNode>[];
  List<RuntimeRunEvent> _events = const <RuntimeRunEvent>[];
  RuntimeResumeSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final nodes = await widget.store.listNodes(widget.run.id);
    final events = await widget.store.listEvents(widget.run.id);
    final snapshot = await widget.store.buildResumeSnapshot(widget.run.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _nodes = nodes;
      _events = events;
      _snapshot = snapshot;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const NeroBackdrop(),
          SafeArea(
            child: Column(
              children: <Widget>[
                NeroTopBar(
                  title: run.title.isEmpty ? run.kind.name : run.title,
                  subtitle: '${run.id} · ${formatDateTime(run.createdAtEpochMs)}',
                  onBackTap: () => Navigator.of(context).maybePop(),
                  actions: <Widget>[
                    HeaderIconButton(
                      icon: Icons.refresh_rounded,
                      semanticLabel: 'Reload run',
                      onTap: _load,
                    ),
                  ],
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                          children: <Widget>[
                            if (_snapshot != null) _buildResumeCard(_snapshot!),
                            _buildNodesCard(),
                            const SizedBox(height: 12),
                            _buildEventsCard(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeCard(RuntimeResumeSnapshot snapshot) {
    final canResume = snapshot.canResume;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InlineBanner(
        message: canResume
            ? 'This run can resume from '
                  '${snapshot.activeNodes.isEmpty ? 'its last phase' : snapshot.activeNodes.first.phaseKey}.'
            : snapshot.resumeReason.isEmpty
            ? 'This run cannot be resumed automatically.'
            : snapshot.resumeReason,
        tone: canResume ? InlineBannerTone.success : InlineBannerTone.info,
        icon: canResume
            ? Icons.play_circle_outline_rounded
            : Icons.info_outline_rounded,
      ),
    );
  }

  Widget _buildNodesCard() {
    return SectionCard(
      title: 'Phases',
      subtitle: _nodes.isEmpty
          ? 'No phase nodes were recorded for this run.'
          : '${_nodes.length} node(s), in execution order',
      child: Column(
        children: <Widget>[
          for (final node in _nodes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: NeroTile(
                title: node.title.isEmpty ? node.phaseKey : node.title,
                subtitle: _nodeSubtitle(node),
                icon: _nodeIcon(node.status),
                accentColor: _nodeColor(node.status),
                dense: true,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                borderRadius: 12,
                trailing: StatusPill(
                  label: node.status.name,
                  color: _nodeColor(node.status),
                  dense: true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsCard() {
    return SectionCard(
      title: 'Event log',
      subtitle: _events.isEmpty
          ? 'No events were recorded.'
          : '${_events.length} event(s)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final event in _events)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      _eventIcon(event.kind),
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          event.title.isEmpty ? event.kind.name : event.title,
                          style: AppTextStyles.body.copyWith(fontSize: 12.6),
                        ),
                        if (event.detail != null &&
                            event.detail!.trim().isNotEmpty)
                          Text(
                            event.detail!,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11.2,
                              height: 1.35,
                            ),
                          ),
                        Text(
                          formatDateTime(event.createdAtEpochMs),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10.2,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _nodeSubtitle(RuntimeRunNode node) {
    final parts = <String>[
      if (node.phaseKey.isNotEmpty) node.phaseKey,
      if (node.toolName != null) node.toolName!,
      if (node.capabilityKey != null) node.capabilityKey!,
      if (node.attempt > 1) 'attempt ${node.attempt}',
      if (node.completedAtEpochMs != null &&
          node.completedAtEpochMs! > node.startedAtEpochMs)
        formatDurationMs(node.completedAtEpochMs! - node.startedAtEpochMs),
      if (node.error != null && node.error!.isNotEmpty) node.error!,
    ];
    return parts.join(' · ');
  }

  IconData _nodeIcon(RuntimeRunNodeStatus status) {
    return switch (status) {
      RuntimeRunNodeStatus.completed => Icons.check_circle_outline_rounded,
      RuntimeRunNodeStatus.running => Icons.play_circle_outline_rounded,
      RuntimeRunNodeStatus.failed => Icons.error_outline_rounded,
      RuntimeRunNodeStatus.blocked => Icons.lock_outline_rounded,
      RuntimeRunNodeStatus.skipped => Icons.skip_next_rounded,
      RuntimeRunNodeStatus.cancelled => Icons.cancel_outlined,
      _ => Icons.circle_outlined,
    };
  }

  Color _nodeColor(RuntimeRunNodeStatus status) {
    return switch (status) {
      RuntimeRunNodeStatus.completed => AppColors.tealBright,
      RuntimeRunNodeStatus.running => AppColors.amber,
      RuntimeRunNodeStatus.failed => AppColors.error,
      RuntimeRunNodeStatus.blocked => AppColors.orange,
      _ => AppColors.textMuted,
    };
  }

  IconData _eventIcon(RuntimeRunEventKind kind) {
    final name = kind.name;
    if (name.contains('error') || name.contains('fail')) {
      return Icons.error_outline_rounded;
    }
    if (name.contains('tool')) {
      return Icons.build_outlined;
    }
    if (name.contains('artefact') || name.contains('artifact')) {
      return Icons.insert_drive_file_outlined;
    }
    return Icons.circle_outlined;
  }
}
