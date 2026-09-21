import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/assistant_thinking_session.dart';
import 'package:nero/features/chat/domain/chat_message.dart';

void main() {
  test('updateCurrentThought does not promote placeholder thoughts on transition', () {
    final session = AssistantThinkingSession();

    session.updateCurrentThought('Planning response');
    session.updateCurrentThought('Searching the web');

    expect(session.currentThought, 'Searching the web');
    expect(session.completedThoughts, isEmpty);
  });

  test('updateCurrentThought completes current thought when requested', () {
    final session = AssistantThinkingSession();

    session.updateCurrentThought('Searching the web');
    session.updateCurrentThought(null, completeCurrent: true);

    expect(session.currentThought, isNull);
    expect(session.completedThoughts, ['Searching the web']);
  });

  test('visibleActivities includes reasoning header and recorded activities', () {
    final session = AssistantThinkingSession();
    session.updateCurrentThought('Searching the web');
    session.recordToolActivity(
      const ChatActivity(
        type: ChatActivityType.webSearch,
        title: 'Searched the web',
        items: <ChatActivityItem>[ChatActivityItem(title: 'Result')],
        isComplete: true,
      ),
    );

    final activities = session.visibleActivities(
      isStreaming: true,
      thoughtTitle: 'Reasoning',
    );

    expect(activities, hasLength(2));
    expect(activities.first.type, ChatActivityType.thought);
    expect(activities.last.title, 'Searched the web');
  });
}
