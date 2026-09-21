import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/docs/application/doc_generation_service.dart';
import 'package:nero/features/docs/application/inline_artifact_generator.dart';
import 'package:nero/features/docs/domain/doc_models.dart';
import 'package:nero/features/tools/application/local_tool_runtime_service.dart';
import 'package:nero/features/tools/domain/tool_runtime_models.dart' as runtime;
import 'package:nero/features/tools/domain/tool_types.dart';
import 'package:nero/features/workspace/domain/workspace_item.dart';
import 'package:nero/platform/device/native_bridge_service.dart';

void main() {
  test('generateDocxArtifact returns a generated artifact reference', () async {
    final generator = InlineArtifactGenerator(
      docGenerationService: _FakeDocGenerationService(),
      localToolRuntimeService: _FakeLocalToolRuntimeService(),
    );

    final artifact = await generator.generateDocxArtifact(
      conversationId: 'conversation_1',
      messageId: 'assistant_1',
      title: 'Test Doc',
      markdownContent: '# Hello',
      blocks: const <DocBlock>[HeadingBlock(level: 1, text: 'Hello')],
    );

    expect(artifact, isNotNull);
    expect(artifact!.title, 'Test Doc.docx');
    expect(artifact.extension, 'docx');
  });

  test('generatePdfArtifact returns a generated artifact reference', () async {
    final generator = InlineArtifactGenerator(
      docGenerationService: _FakeDocGenerationService(),
      localToolRuntimeService: _FakeLocalToolRuntimeService(),
    );

    final artifact = await generator.generatePdfArtifact(
      conversationId: 'conversation_1',
      messageId: 'assistant_1',
      title: 'Test PDF',
      markdownContent: '# Hello',
      blocks: const <DocBlock>[HeadingBlock(level: 1, text: 'Hello')],
    );

    expect(artifact, isNotNull);
    expect(artifact!.title, 'Test PDF.pdf');
    expect(artifact.extension, 'pdf');
  });
}

class _FakeDocGenerationService extends DocGenerationService {
  @override
  Future<WorkspaceItem> generateDocx({
    required DocRequest request,
    String? conversationId,
    String? messageId,
  }) async {
    return WorkspaceItem(
      id: 'docx_1',
      conversationId: conversationId ?? 'standalone',
      type: WorkspaceItemType.generatedArtifact,
      title: '${request.title}.docx',
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
      localPath: 'C:\\temp\\${request.title}.docx',
      extension: 'docx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      sizeBytes: 42,
      metadataJson: '{"previewMarkdown":"# Hello"}',
    );
  }
}

class _FakeLocalToolRuntimeService extends LocalToolRuntimeService {
  _FakeLocalToolRuntimeService()
      : super(nativeBridgeService: NativeBridgeService());

  @override
  Future<runtime.ToolExecutionResult> executeToolRequest({
    required runtime.ToolExecutionRequest request,
    void Function(runtime.RuntimeJobStatus p1)? onStatusChange,
  }) async {
    expect(request.toolType, ToolType.generateReportPdf);
    return const runtime.ToolExecutionResult(
      jobId: 'pdf_1',
      status: runtime.RuntimeJobStatus.completed,
      artifacts: <runtime.GeneratedArtifactDescriptor>[
        runtime.GeneratedArtifactDescriptor(
          id: 'pdf_artifact_1',
          title: 'Test PDF.pdf',
          kindLabel: 'PDF',
          localPath: 'C:\\temp\\Test PDF.pdf',
          extension: 'pdf',
          mimeType: 'application/pdf',
          sizeBytes: 24,
        ),
      ],
    );
  }
}
