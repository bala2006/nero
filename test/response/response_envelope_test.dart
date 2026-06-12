import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/response/response.dart';

void main() {
  test('buildFromChatMessage preserves content, artifacts, and run summary', () {
    final builder = ResponseEnvelopeBuilder();
    final message = ChatMessage(
      id: 'message_1',
      role: ChatRole.assistant,
      content: 'I created the document and attached it below.',
      generatedArtifacts: const <GeneratedArtifactReference>[
        GeneratedArtifactReference(
          id: 'artifact_1',
          title: 'Nero Tools.docx',
          kindLabel: 'DOCX document',
          extension: 'docx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          localPath: '/tmp/Nero Tools.docx',
          sizeBytes: 4096,
        ),
      ],
    );

    final envelope = builder.buildFromChatMessage(
      message: message,
      activities: const <ActivityTrace>[
        ActivityTrace(
          id: 'trace_1',
          type: ActivityTraceType.finalization,
          title: 'Final response prepared',
          detail: 'Attached the generated DOCX artifact.',
        ),
      ],
      runId: 'run_1',
      conversationId: 'conversation_1',
      modelId: 'sarvam-105b',
      title: 'Document generation',
      verified: true,
      reviewedByVerifier: true,
      metadata: const <String, Object?>{'route': 'artifact_first'},
    );

    expect(envelope.summaryText, message.content);
    expect(envelope.displayText, message.content);
    expect(envelope.blocks, hasLength(3));
    expect(envelope.blocks[0], isA<ResponseMarkdownBlock>());
    expect(envelope.blocks[1], isA<ResponseActivityBlock>());
    expect(envelope.blocks[2], isA<ResponseArtifactBlock>());
    expect(envelope.artifacts, hasLength(1));
    expect(envelope.artifacts.single.artifactId, 'artifact_1');
    expect(envelope.activities.single.type, ActivityTraceType.finalization);
    expect(envelope.runSummary, isNotNull);
    expect(envelope.runSummary!.runId, 'run_1');
    expect(envelope.runSummary!.title, 'Document generation');
    expect(envelope.runSummary!.artifactCount, 1);
    expect(envelope.runSummary!.activityCount, 1);
    expect(envelope.quality.verified, isTrue);
    expect(envelope.quality.reviewedByVerifier, isTrue);
  });

  test('response envelope round-trips through JSON without losing structure', () {
    final envelope = ResponseEnvelope(
      summaryText: 'Created the requested PDF.',
      blocks: <ResponseBlock>[
        const ResponseMarkdownBlock(
          content: 'Created the requested PDF.',
          title: 'Final answer',
          metadata: <String, Object?>{'tone': 'brief'},
        ),
        const ResponseActivityBlock(
          trace: ActivityTrace(
            id: 'trace_1',
            type: ActivityTraceType.planning,
            title: 'Planning response',
            detail: 'Selected the PDF route.',
          ),
        ),
        const ResponseArtifactBlock(
          reference: ResponseArtifactReference(
            artifactId: 'artifact_1',
            title: 'Nero Capabilities.pdf',
            kindLabel: 'PDF document',
            extension: 'pdf',
            mimeType: 'application/pdf',
            localPath: '/tmp/Nero Capabilities.pdf',
            sizeBytes: 1024,
          ),
          note: 'Generated artifact attached.',
        ),
        const ResponseRawBlock(
          content: 'legacy content',
          label: 'fallback',
        ),
      ],
      artifacts: const <ResponseArtifactReference>[
        ResponseArtifactReference(
          artifactId: 'artifact_1',
          title: 'Nero Capabilities.pdf',
          kindLabel: 'PDF document',
          extension: 'pdf',
          mimeType: 'application/pdf',
          localPath: '/tmp/Nero Capabilities.pdf',
          sizeBytes: 1024,
        ),
      ],
      activities: const <ActivityTrace>[
        ActivityTrace(
          id: 'trace_1',
          type: ActivityTraceType.planning,
          title: 'Planning response',
          detail: 'Selected the PDF route.',
        ),
      ],
      runSummary: const RunSummary(
        runId: 'run_1',
        title: 'PDF response',
        status: 'completed',
        summaryText: 'Created the requested PDF.',
        conversationId: 'conversation_1',
        modelId: 'sarvam-105b',
        artifactCount: 1,
        activityCount: 1,
        verified: true,
        reviewedByVerifier: true,
        completedAtEpochMs: 1234,
      ),
      quality: const ResponseQuality(
        verified: true,
        reviewedByVerifier: true,
        score: 0.92,
        notes: <String>['verified'],
        metadata: <String, Object?>{'verifier': 'unit'},
      ),
      metadata: const <String, Object?>{'route': 'balanced'},
    );

    final decoded = ResponseEnvelope.fromJson(
      jsonDecode(jsonEncode(envelope.toJson())) as Map<String, dynamic>,
    );

    expect(decoded.summaryText, envelope.summaryText);
    expect(decoded.displayText, envelope.displayText);
    expect(decoded.blocks, hasLength(4));
    expect(decoded.blocks[0], isA<ResponseMarkdownBlock>());
    expect(decoded.blocks[1], isA<ResponseActivityBlock>());
    expect(decoded.blocks[2], isA<ResponseArtifactBlock>());
    expect(decoded.blocks[3], isA<ResponseRawBlock>());

    final artifactBlock = decoded.blocks[2] as ResponseArtifactBlock;
    expect(artifactBlock.reference.artifactId, 'artifact_1');
    expect(artifactBlock.reference.title, 'Nero Capabilities.pdf');
    expect(decoded.runSummary, isNotNull);
    expect(decoded.runSummary!.isTerminal, isTrue);
    expect(decoded.runSummary!.artifactCount, 1);
    expect(decoded.runSummary!.activityCount, 1);
    expect(decoded.quality.verified, isTrue);
    expect(decoded.quality.reviewedByVerifier, isTrue);
    expect(decoded.quality.score, 0.92);
    expect(decoded.metadata['route'], 'balanced');
  });
}
