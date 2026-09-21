import 'package:flutter/material.dart';

import '../../../core/format/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../../audit/application/audit_log_store.dart';
import '../../audit/domain/app_capability.dart';
import '../../audit/domain/audit_log_entry.dart';
import '../application/memory_store.dart';
import '../application/semantic_fact_store.dart';
import '../domain/memory_entry.dart';
import '../domain/semantic_fact.dart';

/// Everything Nero has written down about the user and their conversations.
///
/// The stores already existed and were written to during every turn; this
/// screen is what makes them inspectable and deletable, which is the other half
/// of the "memory" feature.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _factScopes = <String>[
    'conversation',
    'workspace',
    'task',
  ];

  final MemoryStore _memoryStore = MemoryStore();
  final SemanticFactStore _semanticFactStore = SemanticFactStore();
  final AuditLogStore _auditLogStore = AuditLogStore();

  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  bool _loading = true;
  String? _error;
  List<MemoryEntry> _entries = const <MemoryEntry>[];
  final Map<String, List<SemanticFact>> _factsByScope =
      <String, List<SemanticFact>>{};
  MemoryEntryKind? _kindFilter;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _memoryStore.listEntries(limit: 200);
      final facts = <String, List<SemanticFact>>{};
      for (final scope in _factScopes) {
        facts[scope] = await _semanticFactStore.listFacts(scope: scope);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _factsByScope
          ..clear()
          ..addAll(facts);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not read stored memory: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final factCount = _factsByScope.values.fold<int>(
      0,
      (total, facts) => total + facts.length,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const NeroBackdrop(),
          SafeArea(
            child: Column(
              children: <Widget>[
                NeroTopBar(
                  title: 'Memory',
                  subtitle:
                      '${_entries.length} entries · $factCount learned facts',
                  onBackTap: () => Navigator.of(context).maybePop(),
                  actions: <Widget>[
                    HeaderIconButton(
                      icon: Icons.refresh_rounded,
                      semanticLabel: 'Reload memory',
                      onTap: _load,
                    ),
                  ],
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.orange,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.orange,
                  tabs: const <Widget>[
                    Tab(text: 'Entries'),
                    Tab(text: 'Learned facts'),
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
                      : _buildBody(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
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
    return TabBarView(
      controller: _tabController,
      children: <Widget>[_buildEntriesTab(), _buildFactsTab()],
    );
  }

  // ---- entries ------------------------------------------------------------

  Widget _buildEntriesTab() {
    final filtered = _kindFilter == null
        ? _entries
        : _entries
              .where((entry) => entry.kind == _kindFilter)
              .toList(growable: false);

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
                selected: _kindFilter == null,
                accentColor: AppColors.orange,
                onTap: () => setState(() => _kindFilter = null),
              ),
              for (final kind in MemoryEntryKind.values) ...<Widget>[
                const SizedBox(width: 6),
                NeroActionChip(
                  label: _kindLabel(kind),
                  selected: _kindFilter == kind,
                  accentColor: AppColors.orange,
                  onTap: () => setState(() => _kindFilter = kind),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.psychology_outlined,
                  title: 'Nothing stored here yet',
                  message:
                      'Nero records episodic summaries, artifacts and context '
                      'snapshots as you use the app.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildEntryCard(filtered[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(MemoryEntry entry) {
    return SectionCard(
      title: entry.title.isEmpty ? _kindLabel(entry.kind) : entry.title,
      subtitle: '${_kindLabel(entry.kind)} · ${entry.scope} · '
          '${formatRelativeTime(entry.updatedAtEpochMs)}',
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        color: AppColors.error,
        tooltip: 'Forget this entry',
        onPressed: () => _forgetEntry(entry),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (entry.summary != null && entry.summary!.trim().isNotEmpty)
            Text(
              entry.summary!,
              style: AppTextStyles.bodySecondary.copyWith(
                fontSize: 12.4,
                height: 1.4,
              ),
            ),
          if (entry.content.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _stringify(entry.content, maxLength: 700),
                style: AppTextStyles.codeMono(
                  color: AppColors.textSecondary,
                  fontSize: 10.6,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (entry.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final tag in entry.tags)
                  StatusPill(
                    label: tag,
                    color: AppColors.textMuted,
                    dense: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---- facts --------------------------------------------------------------

  Widget _buildFactsTab() {
    final scopes = _factsByScope.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList(growable: false);
    if (scopes.isEmpty) {
      return const EmptyState(
        icon: Icons.lightbulb_outline_rounded,
        title: 'No learned facts yet',
        message:
            'Facts are captured when a conversation settles on something worth '
            'reusing later.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: <Widget>[
        const InlineBanner(
          message:
              'Facts carry a confidence score. Lower-confidence facts are '
              'shown to the model as a hint, never as a fact.',
          tone: InlineBannerTone.info,
        ),
        const SizedBox(height: 12),
        for (final scope in scopes) ...<Widget>[
          SectionCard(
            title: _scopeLabel(scope.key),
            subtitle: '${scope.value.length} fact(s)',
            child: Column(
              children: <Widget>[
                for (final fact in scope.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _buildFactRow(fact),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildFactRow(SemanticFact fact) {
    return NeroTile(
      title: fact.key,
      subtitle: fact.value.isEmpty
          ? 'No stored value'
          : _stringify(fact.value, maxLength: 220),
      icon: Icons.tag_rounded,
      dense: true,
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      borderRadius: 12,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatusPill(
            label: '${(fact.confidence * 100).round()}%',
            color: fact.confidence >= 0.7
                ? AppColors.tealBright
                : AppColors.amber,
            dense: true,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppColors.error,
            tooltip: 'Forget this fact',
            onPressed: () => _forgetFact(fact),
          ),
        ],
      ),
    );
  }

  // ---- actions ------------------------------------------------------------

  Future<void> _forgetEntry(MemoryEntry entry) async {
    final confirmed = await _confirm(
      title: 'Forget this entry?',
      message:
          'Nero will stop using "${entry.title}" in future turns. This cannot '
          'be undone.',
    );
    if (!confirmed) {
      return;
    }
    await _memoryStore.deleteEntry(entry.id);
    await _audit(
      detail: 'Forgot memory entry ${entry.id} (${entry.kind.name}).',
    );
    await _load();
  }

  Future<void> _forgetFact(SemanticFact fact) async {
    final confirmed = await _confirm(
      title: 'Forget this fact?',
      message: 'The key "${fact.key}" will be removed from ${fact.scope} memory.',
    );
    if (!confirmed) {
      return;
    }
    await _semanticFactStore.deleteFact(fact.id);
    await _audit(detail: 'Forgot semantic fact ${fact.key} (${fact.scope}).');
    await _load();
  }

  Future<void> _audit({required String detail}) async {
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.memoryForget.key,
      title: AppCapabilities.memoryForget.label,
      detail: detail,
      status: AuditLogStatus.success,
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(title, style: AppTextStyles.titleSmall),
        content: Text(
          message,
          style: AppTextStyles.bodySecondary.copyWith(fontSize: 12.8),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Keep',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textMuted,
                fontSize: 12.6,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Forget',
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
                fontSize: 12.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ---- helpers ------------------------------------------------------------

  String _kindLabel(MemoryEntryKind kind) {
    return switch (kind) {
      MemoryEntryKind.working => 'Working',
      MemoryEntryKind.episodic => 'Episodic',
      MemoryEntryKind.semantic => 'Semantic',
      MemoryEntryKind.artifact => 'Artifact',
      MemoryEntryKind.contextSnapshot => 'Context snapshot',
    };
  }

  String _scopeLabel(String scope) {
    return switch (scope) {
      'conversation' => 'Conversation facts',
      'workspace' => 'Workspace facts',
      'task' => 'Task facts',
      _ => '$scope facts',
    };
  }

  String _stringify(Map<String, Object?> value, {required int maxLength}) {
    final buffer = StringBuffer();
    value.forEach((key, entry) {
      buffer.writeln('$key: ${entry ?? 'null'}');
    });
    final text = buffer.toString().trimRight();
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}…';
  }
}
