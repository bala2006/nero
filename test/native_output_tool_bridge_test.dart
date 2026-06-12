import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/native_output_tool_bridge.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/docs/application/artifact_result_adapter.dart';
import 'package:nero/features/tools/application/local_tool_runtime_service.dart';
import 'package:nero/features/tools/domain/tool_runtime_models.dart' as runtime;
import 'package:nero/features/tools/domain/tool_types.dart';
import 'package:nero/platform/device/native_bridge_service.dart';

void main() {
  test('execute applies artifacts and activity from native runtime result', () async {
    final bridge = NativeOutputToolBridge(
      localToolRuntimeService: _FakeLocalToolRuntimeService(),
      artifactResultAdapter: const ArtifactResultAdapter(),
    );
    final artifacts = <GeneratedArtifactReference>[];
    final activities = <ChatActivity>[];

    final result = await bridge.execute(
      toolType: ToolType.generateReportPdf,
      title: 'Report',
      parameters: const <String, dynamic>{'title': 'Report'},
      conversationId: 'conversation_1',
      messageId: 'assistant_1',
      successSummary: 'Created PDF document',
      failurePrefix: 'PDF generation failed',
      onArtifact: artifacts.add,
      onActivity: activities.add,
    );

    expect(result.success, isTrue);
    expect(artifacts, hasLength(1));
    expect(activities, hasLength(1));
    expect(artifacts.single.title, 'Report.pdf');
    expect(activities.single.title, 'Created file');
  });
}

class _FakeLocalToolRuntimeService extends LocalToolRuntimeService {
  _FakeLocalToolRuntimeService()
      : super(nativeBridgeService: NativeBridgeService());

  @override
  Future<runtime.ToolExecutionResult> executeToolRequest({
    required runtime.ToolExecutionRequest request,
    void Function(runtime.RuntimeJobStatus p1)? onStatusChange,
  }) async {
    return const runtime.ToolExecutionResult(
      jobId: 'job_1',
      status: runtime.RuntimeJobStatus.completed,
      artifacts: <runtime.GeneratedArtifactDescriptor>[
        runtime.GeneratedArtifactDescriptor(
          id: 'artifact_1',
          title: 'Report.pdf',
          kindLabel: 'PDF',
          localPath: 'C:\\temp\\Report.pdf',
          extension: 'pdf',
          mimeType: 'application/pdf',
          sizeBytes: 64,
        ),
      ],
    );
  }
}
