import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/audit/domain/audit_log_entry.dart';
import 'package:nero/features/chat/domain/chat_message.dart';
import 'package:nero/features/workspace/application/document_export_service.dart';
import 'package:nero/features/workspace/domain/workspace_item.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('nero/document_export');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('exports markdown assistant messages through document channel', () async {
    final workspaceStore = FakeWorkspaceStore();
    final auditLogStore = FakeAuditLogStore();
    Uint8List? writtenBytes;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'createDocument':
          expect(call.arguments['mimeType'], 'text/markdown');
          expect(call.arguments['suggestedName'], contains('.md'));
          return 'content://exports/markdown';
        case 'writeDocument':
          writtenBytes = call.arguments['bytes'] as Uint8List;
          expect(call.arguments['uri'], 'content://exports/markdown');
          return <String, Object?>{'sizeBytes': writtenBytes!.length};
      }
      return null;
    });

    final service = DocumentExportService(
      workspaceStore: workspaceStore,
      auditLogStore: auditLogStore,
      temporaryDirectoryProvider: () async => Directory.systemTemp.createTempSync(
        'nero_export_test_',
      ),
    );

    final result = await service.exportAssistantMessage(
      message: ChatMessage(
        id: 'assistant_1',
        role: ChatRole.assistant,
        content: '''
# Release Summary
[[NERO_BLOCK:CODE lang=dart]]
print("hi");
[[/NERO_BLOCK]]
''',
      ),
      conversationId: 'conversation_1',
      format: ExportDocumentFormat.markdown,
    );

    expect(result, isNotNull);
    expect(workspaceStore.savedItems, hasLength(1));
    expect(workspaceStore.savedItems.single.type, WorkspaceItemType.generatedArtifact);
    expect(workspaceStore.savedItems.single.sourceUri, 'content://exports/markdown');
    expect(utf8.decode(writtenBytes!), contains('```dart'));
    expect(utf8.decode(writtenBytes!), isNot(contains('[[NERO_BLOCK:CODE')));
    expect(auditLogStore.entries, hasLength(2));
    expect(auditLogStore.entries.first.status, AuditLogStatus.started);
    expect(auditLogStore.entries.last.status, AuditLogStatus.success);
  });

  test('cancelled export does not persist a workspace artifact', () async {
    final workspaceStore = FakeWorkspaceStore();
    final auditLogStore = FakeAuditLogStore();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'createDocument') {
        return null;
      }
      fail('writeDocument should not be called after cancellation.');
    });

    final service = DocumentExportService(
      workspaceStore: workspaceStore,
      auditLogStore: auditLogStore,
      temporaryDirectoryProvider: () async => Directory.systemTemp.createTempSync(
        'nero_export_test_',
      ),
    );

    final result = await service.exportAssistantMessage(
      message: const ChatMessage(
        id: 'assistant_2',
        role: ChatRole.assistant,
        content: 'Plain response',
      ),
      conversationId: 'conversation_2',
      format: ExportDocumentFormat.text,
    );

    expect(result, isNull);
    expect(workspaceStore.savedItems, isEmpty);
    expect(auditLogStore.entries, hasLength(2));
    expect(auditLogStore.entries.last.status, AuditLogStatus.success);
    expect(auditLogStore.entries.last.detail, contains('cancelled'));
  });

  test('zip export writes a real zip archive', () async {
    final workspaceStore = FakeWorkspaceStore();
    final auditLogStore = FakeAuditLogStore();
    Uint8List? writtenBytes;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'createDocument':
          expect(call.arguments['mimeType'], 'application/zip');
          expect(call.arguments['suggestedName'], contains('.zip'));
          return 'content://exports/archive';
        case 'writeDocument':
          writtenBytes = call.arguments['bytes'] as Uint8List;
          return <String, Object?>{'sizeBytes': writtenBytes!.length};
      }
      return null;
    });

    final service = DocumentExportService(
      workspaceStore: workspaceStore,
      auditLogStore: auditLogStore,
      temporaryDirectoryProvider: () async => Directory.systemTemp.createTempSync(
        'nero_export_test_',
      ),
    );

    final result = await service.exportAssistantMessage(
      message: const ChatMessage(
        id: 'assistant_zip',
        role: ChatRole.assistant,
        content: '# Summary\n\nSome content.',
      ),
      conversationId: 'conversation_zip',
      format: ExportDocumentFormat.zip,
    );

    expect(result, isNotNull);
    expect(writtenBytes, isNotNull);
    expect(writtenBytes![0], 0x50);
    expect(writtenBytes![1], 0x4B);
  });

  test('exportExistingWorkspaceItem preserves preview metadata for repeated downloads', () async {
    final workspaceStore = FakeWorkspaceStore();
    final auditLogStore = FakeAuditLogStore();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'createDocument':
          return 'content://exports/docx';
        case 'writeDocument':
          return <String, Object?>{'sizeBytes': 4};
      }
      return null;
    });

    final tempDir = Directory.systemTemp.createTempSync('nero_export_existing_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final file = File('${tempDir.path}${Platform.pathSeparator}doc.docx');
    await file.writeAsBytes(const <int>[1, 2, 3, 4], flush: true);

    final service = DocumentExportService(
      workspaceStore: workspaceStore,
      auditLogStore: auditLogStore,
      temporaryDirectoryProvider: () async => tempDir,
    );

    final result = await service.exportExistingWorkspaceItem(
      item: WorkspaceItem(
        id: 'artifact_1',
        conversationId: 'conversation_1',
        type: WorkspaceItemType.generatedArtifact,
        title: 'What I Can Do.docx',
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        localPath: file.path,
        extension: 'docx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        sizeBytes: 4,
        metadataJson: jsonEncode(<String, Object?>{
          'previewMarkdown': '# What I Can Do\n\n- Help with coding',
        }),
      ),
      conversationId: 'conversation_1',
    );

    expect(result, isNotNull);
    expect(workspaceStore.savedItems, hasLength(1));
    final metadata = jsonDecode(workspaceStore.savedItems.single.metadataJson!)
        as Map<String, dynamic>;
    expect(metadata['previewMarkdown'], contains('What I Can Do'));
    expect(workspaceStore.savedItems.single.sourceUri, 'content://exports/docx');
  });
}
