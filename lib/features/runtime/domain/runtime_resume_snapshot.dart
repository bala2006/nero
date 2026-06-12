import 'runtime_run.dart';
import 'runtime_run_node.dart';

class RuntimeResumeSnapshot {
  const RuntimeResumeSnapshot({
    required this.run,
    required this.nodes,
    required this.activeNodes,
    required this.canResume,
    required this.resumeReason,
  });

  final RuntimeRun run;
  final List<RuntimeRunNode> nodes;
  final List<RuntimeRunNode> activeNodes;
  final bool canResume;
  final String resumeReason;
}
