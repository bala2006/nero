import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/native_docx_tool_bridge.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/docs/application/artifact_result_adapter.dart';
import 'package:nero/features/docs/application/doc_generation_service.dart';
import 'package:nero/features/docs/domain/doc_models.dart';
import 'package:nero/features/workspace/domain/workspace_item.dart';

void main() {
  test('execute applies workspace-item artifact and activity for DOCX output', () async {
    final bridge = NativeDocxToolBridge(
      docGenerationService: _FakeDocGenerationService(),
      artifactResultAdapter: const ArtifactResultAdapter(),
    );
    final artifacts = <GeneratedArtifactReference>[];
    final activities = <ChatActivity>[];

    final result = await bridge.execute(
      title: 'Capabilities',
      blocks: const <DocBlock>[ParagraphBlock(text: 'Nero can create docs.')],
      conversationId: 'conversation_1',
      messageId: 'assistant_1',
      onArtifact: artifacts.add,
      onActivity: activities.add,
    );

    expect(result.success, isTrue);
    expect(artifacts, hasLength(1));
    expect(activities, hasLength(1));
    expect(artifacts.single.title, 'Capabilities.docx');
    expect(activities.single.title, 'Created document');
  });
}

class _FakeDocGenerationService extends DocGenerationService {
  _FakeDocGenerationService() : super();

  @override
  Future<WorkspaceItem> generateDocx({
    required DocRequest request,
    String? conversationId,
    String? messageId,
  }) async {
    return WorkspaceItem(
      id: 'artifact_1',
      conversationId: conversationId ?? 'conversation_1',
      type: WorkspaceItemType.generatedArtifact,
      title: 'Capabilities.docx',
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
      localPath: 'C:\\temp\\Capabilities.docx',
      extension: 'docx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      sizeBytes: 128,
      metadataJson:
          '{"previewMarkdown":"# Capabilities\\n\\nNero can create docs."}',
    );
  }
}
