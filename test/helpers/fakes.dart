import 'package:nero/features/audit/application/audit_log_store.dart';
import 'package:nero/features/audit/domain/audit_log_entry.dart';
import 'package:nero/features/workspace/application/workspace_store.dart';
import 'package:nero/features/workspace/domain/workspace_item.dart';
import 'package:nero/platform/device/native_bridge_service.dart';

/// Records every [WorkspaceItem] written through [upsertItem] so tests can
/// assert on what the service under test persisted.
class FakeWorkspaceStore extends WorkspaceStore {
  final List<WorkspaceItem> savedItems = <WorkspaceItem>[];

  @override
  Future<void> upsertItem(WorkspaceItem item) async {
    savedItems.add(item);
  }
}

/// Records every audit entry written through [record] and replays them,
/// newest first, through [listRecent].
class FakeAuditLogStore extends AuditLogStore {
  final List<AuditLogEntry> entries = <AuditLogEntry>[];

  @override
  Future<void> record({
    required String capabilityKey,
    required String title,
    required AuditLogStatus status,
    String? detail,
    String? conversationId,
  }) async {
    entries.add(
      AuditLogEntry(
        id: 'audit_${entries.length}',
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        capabilityKey: capabilityKey,
        title: title,
        status: status,
        detail: detail,
        conversationId: conversationId,
      ),
    );
  }

  @override
  Future<List<AuditLogEntry>> listRecent({int limit = 20}) async {
    return entries.reversed.take(limit).toList(growable: false);
  }
}

/// Stubs the platform tool channel. [artifacts] is returned verbatim from
/// [executeToolRequest] and defaults to an empty result set.
class FakeNativeBridgeService extends NativeBridgeService {
  FakeNativeBridgeService({this.artifacts = const <Map<String, dynamic>>[]});

  final List<Map<String, dynamic>> artifacts;

  @override
  Future<List<Map<String, dynamic>>> executeToolRequest(
    String jobId,
    String toolTypeName,
    Map<String, dynamic> parameters,
  ) async {
    return artifacts;
  }
}
