import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/chat_message_state_store.dart';
import 'package:nero/features/chat/domain/chat_message.dart';

void main() {
  test('indexOfMessageId tracks appended and replaced messages', () {
    final store = ChatMessageStateStore();

    store.appendMessages(
      const <ChatMessage>[
        ChatMessage(id: 'm1', role: ChatRole.user, content: 'hi'),
        ChatMessage(id: 'm2', role: ChatRole.assistant, content: 'hello'),
      ],
      estimateTokens: (message) => message.content.length,
    );

    expect(store.indexOfMessageId('m1'), 0);
    expect(store.indexOfMessageId('m2'), 1);

    store.replaceMessageAt(
      1,
      const ChatMessage(id: 'm2', role: ChatRole.assistant, content: 'hello again'),
      estimateTokens: (message) => message.content.length,
    );

    expect(store.indexOfMessageId('m2'), 1);

    store.replaceMessageAt(
      1,
      const ChatMessage(id: 'm3', role: ChatRole.assistant, content: 'renamed'),
      estimateTokens: (message) => message.content.length,
    );

    expect(store.indexOfMessageId('m2'), -1);
    expect(store.indexOfMessageId('m3'), 1);

    store.dispose();
  });

  test('indexOfMessageId resets on replaceAllMessages', () {
    final store = ChatMessageStateStore();

    store.appendMessages(
      const <ChatMessage>[
        ChatMessage(id: 'm1', role: ChatRole.user, content: 'hi'),
      ],
      estimateTokens: (message) => message.content.length,
    );

    store.replaceAllMessages(
      const <ChatMessage>[
        ChatMessage(id: 'm10', role: ChatRole.user, content: 'next'),
        ChatMessage(id: 'm11', role: ChatRole.assistant, content: 'done'),
      ],
      estimateTokens: (message) => message.content.length,
    );

    expect(store.indexOfMessageId('m1'), -1);
    expect(store.indexOfMessageId('m10'), 0);
    expect(store.indexOfMessageId('m11'), 1);

    store.dispose();
  });
}
