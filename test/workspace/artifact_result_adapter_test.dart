import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/docs/application/artifact_result_adapter.dart';
import 'package:nero/features/tools/domain/tool_runtime_models.dart' as runtime;
import 'package:nero/features/workspace/domain/workspace_item.dart';

void main() {
  const adapter = ArtifactResultAdapter();

  test('referenceForWorkspaceItem maps workspace metadata into artifact reference', () {
    final item = WorkspaceItem(
      id: 'artifact_1',
      conversationId: 'conversation_1',
      type: WorkspaceItemType.generatedArtifact,
      title: 'Report.docx',
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
      localPath: 'C:\\temp\\Report.docx',
      extension: 'docx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      sizeBytes: 128,
      metadataJson: '{"previewMarkdown":"# Report"}',
    );

    final reference = adapter.referenceForWorkspaceItem(item);

    expect(reference.id, 'artifact_1');
    expect(reference.title, 'Report.docx');
    expect(reference.kindLabel, 'Document');
    expect(reference.previewMarkdown, '# Report');
  });

  test('referenceForDescriptor maps runtime descriptor into artifact reference', () {
    const descriptor = runtime.GeneratedArtifactDescriptor(
      id: 'artifact_2',
      title: 'Report.pdf',
      kindLabel: 'PDF',
      localPath: 'C:\\temp\\Report.pdf',
      extension: 'pdf',
      mimeType: 'application/pdf',
      sizeBytes: 64,
      metadata: <String, dynamic>{'previewMarkdown': '# PDF'},
    );

    final reference = adapter.referenceForDescriptor(descriptor);

    expect(reference.id, 'artifact_2');
    expect(reference.kindLabel, 'PDF');
    expect(reference.previewMarkdown, '# PDF');
  });

  test('toolExecutionResultFromNativeResult formats success output', () {
    const runtimeResult = runtime.ToolExecutionResult(
      jobId: 'job_1',
      status: runtime.RuntimeJobStatus.completed,
      artifacts: <runtime.GeneratedArtifactDescriptor>[
        runtime.GeneratedArtifactDescriptor(
          id: 'artifact_2',
          title: 'Report.pdf',
          kindLabel: 'PDF',
          localPath: 'C:\\temp\\Report.pdf',
          extension: 'pdf',
          mimeType: 'application/pdf',
          sizeBytes: 64,
        ),
      ],
    );

    final result = adapter.toolExecutionResultFromNativeResult(
      runtimeResult: runtimeResult,
      successSummary: 'Created PDF document',
      failurePrefix: 'PDF generation failed',
    );

    expect(result.success, isTrue);
    expect(result.summary, 'Created PDF document "Report.pdf".');
    expect(result.formattedOutput, contains('Created and attached `Report.pdf`'));
    expect(result.items, hasLength(1));
  });

  test('toolExecutionResultFromNativeResult formats failure output', () {
    const runtimeResult = runtime.ToolExecutionResult(
      jobId: 'job_2',
      status: runtime.RuntimeJobStatus.failed,
      errorMessage: 'Native bridge failed',
    );

    final result = adapter.toolExecutionResultFromNativeResult(
      runtimeResult: runtimeResult,
      successSummary: 'Created PDF document',
      failurePrefix: 'PDF generation failed',
    );

    expect(result.success, isFalse);
    expect(result.formattedOutput, 'PDF generation failed: Native bridge failed');
  });

  test('activityForWorkspaceItem formats a completed document activity', () {
    final item = WorkspaceItem(
      id: 'artifact_1',
      conversationId: 'conversation_1',
      type: WorkspaceItemType.generatedArtifact,
      title: 'Report.docx',
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
      localPath: 'C:\\temp\\Report.docx',
      extension: 'docx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      sizeBytes: 128,
    );

    final activity = adapter.activityForWorkspaceItem(
      item: item,
      title: 'Created document',
    );

    expect(activity.title, 'Created document');
    expect(activity.subtitle, 'Report.docx');
    expect(activity.items.single.subtitle, 'Document');
  });

  test('activityForDescriptors formats a completed artifact activity', () {
    const descriptors = <runtime.GeneratedArtifactDescriptor>[
      runtime.GeneratedArtifactDescriptor(
        id: 'artifact_2',
        title: 'Report.pdf',
        kindLabel: 'PDF',
        localPath: 'C:\\temp\\Report.pdf',
        extension: 'pdf',
        mimeType: 'application/pdf',
        sizeBytes: 64,
      ),
    ];

    final activity = adapter.activityForDescriptors(
      descriptors: descriptors,
      title: 'Created file',
    );

    expect(activity.title, 'Created file');
    expect(activity.subtitle, 'Report.pdf');
    expect(activity.items.single.subtitle, 'PDF');
  });

  test('outcomeForWorkspaceItem bundles artifact, activity, and tool result', () {
    final item = WorkspaceItem(
      id: 'artifact_1',
      conversationId: 'conversation_1',
      type: WorkspaceItemType.generatedArtifact,
      title: 'Report.docx',
      createdAtEpochMs: 1,
      updatedAtEpochMs: 1,
      localPath: 'C:\\temp\\Report.docx',
      extension: 'docx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      sizeBytes: 128,
    );

    final outcome = adapter.outcomeForWorkspaceItem(
      item: item,
      successSummary: 'Created DOCX document',
      activityTitle: 'Created document',
      artifactLabel: 'generated DOCX artifact',
    );

    expect(outcome.artifacts, hasLength(1));
    expect(outcome.activity?.title, 'Created document');
    expect(outcome.toolResult.success, isTrue);
    expect(outcome.toolResult.formattedOutput, contains('generated DOCX artifact'));
  });

  test('outcomeForNativeRuntimeResult bundles artifacts and activity on success', () {
    const runtimeResult = runtime.ToolExecutionResult(
      jobId: 'job_1',
      status: runtime.RuntimeJobStatus.completed,
      artifacts: <runtime.GeneratedArtifactDescriptor>[
        runtime.GeneratedArtifactDescriptor(
          id: 'artifact_2',
          title: 'Report.pdf',
          kindLabel: 'PDF',
          localPath: 'C:\\temp\\Report.pdf',
          extension: 'pdf',
          mimeType: 'application/pdf',
          sizeBytes: 64,
        ),
      ],
    );

    final outcome = adapter.outcomeForNativeRuntimeResult(
      runtimeResult: runtimeResult,
      successSummary: 'Created PDF document',
      failurePrefix: 'PDF generation failed',
      activityTitle: 'Created file',
    );

    expect(outcome.artifacts, hasLength(1));
    expect(outcome.activity?.title, 'Created file');
    expect(outcome.toolResult.success, isTrue);
  });
}
