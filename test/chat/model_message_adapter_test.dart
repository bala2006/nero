import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/model_message_adapter.dart';
import 'package:nero/features/chat/domain/chat_message.dart';

void main() {
  const adapter = ModelMessageAdapter();

  test('adapt leaves non-user messages unchanged', () {
    const message = ChatMessage(
      id: 'assistant_1',
      role: ChatRole.assistant,
      content: 'Hello',
    );

    expect(adapter.adapt(message), same(message));
  });

  test('adapt expands user attachments into model-visible context', () {
    const message = ChatMessage(
      id: 'user_1',
      role: ChatRole.user,
      content: 'Summarize this',
      attachments: <ChatAttachment>[
        ChatAttachment(
          id: 'attachment_1',
          title: 'report.pdf',
          kindLabel: 'PDF',
          contextText: 'Quarterly revenue and growth.',
        ),
      ],
    );

    final adapted = adapter.adapt(message);

    expect(adapted.content, contains('Attached files:'));
    expect(adapted.content, contains('report.pdf (PDF)'));
    expect(adapted.content, contains('Quarterly revenue and growth.'));
    expect(adapted.content, contains('User request:\nSummarize this'));
  });
}
