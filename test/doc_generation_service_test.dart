import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/audit/application/audit_log_store.dart';
import 'package:nero/features/audit/domain/audit_log_entry.dart';
import 'package:nero/features/docs/application/doc_generation_service.dart';
import 'package:nero/features/docs/domain/doc_models.dart';
import 'package:nero/features/workspace/application/workspace_store.dart';
import 'package:nero/features/workspace/domain/workspace_item.dart';
import 'package:nero/platform/device/native_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generateDocx uses the native DOCX artifact output', () async {
    final tempDir = await Directory.systemTemp.createTemp('nero_native_doc_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final nativeFile = File('${tempDir.path}\\native_result.docx');
    await nativeFile.writeAsBytes(const <int>[1, 2, 3, 4], flush: true);

    final workspaceStore = FakeWorkspaceStore();
    final auditLogStore = FakeAuditLogStore();
    final service = DocGenerationService(
      workspaceStore: workspaceStore,
      auditLogStore: auditLogStore,
      nativeBridgeService: FakeNativeBridgeService(
        artifacts: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'native_artifact_1',
            'title': 'native_result.docx',
            'localPath': nativeFile.path,
            'extension': 'docx',
            'mimeType':
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'sizeBytes': 4,
            'metadata': <String, Object?>{'jobId': 'native_job'},
          },
        ],
      ),
      documentsDirectoryProvider: () async => tempDir,
    );

    final item = await service.generateDocx(
      request: const DocRequest(
        title: 'Native Preferred',
        blocks: [ParagraphBlock(text: 'Use the native output')],
      ),
      conversationId: 'conversation_native',
      messageId: 'message_native',
    );

    expect(item.id, 'native_artifact_1');
    expect(item.localPath, nativeFile.path);
    expect(item.sizeBytes, 4);
    expect(workspaceStore.savedItems.single.localPath, nativeFile.path);
    final metadata = jsonDecode(
      workspaceStore.savedItems.single.metadataJson!,
    ) as Map<String, dynamic>;
    expect(metadata['previewMarkdown'], contains('Use the native output'));
    expect(
      File('${tempDir.path}\\Native_Preferred.docx').existsSync(),
      isFalse,
    );
  });

  test('generateDocx fails if native DOCX pipeline returns no docx artifact', () async {
    final tempDir = await Directory.systemTemp.createTemp('nero_native_doc_fail_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final service = DocGenerationService(
      workspaceStore: FakeWorkspaceStore(),
      auditLogStore: FakeAuditLogStore(),
      nativeBridgeService: FakeNativeBridgeService(
        artifacts: const <Map<String, dynamic>>[],
      ),
      documentsDirectoryProvider: () async => tempDir,
    );

    await expectLater(
      () => service.generateDocx(
        request: const DocRequest(
          title: 'Native Required',
          blocks: [ParagraphBlock(text: 'Must come from native POI')],
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('native POI pipeline'),
        ),
      ),
    );
  });
}

class FakeWorkspaceStore extends WorkspaceStore {
  final List<WorkspaceItem> savedItems = <WorkspaceItem>[];

  @override
  Future<void> upsertItem(WorkspaceItem item) async {
    savedItems.add(item);
  }
}

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
}

class FakeNativeBridgeService extends NativeBridgeService {
  FakeNativeBridgeService({
    required this.artifacts,
  });

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
