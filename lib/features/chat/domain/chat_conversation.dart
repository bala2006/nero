import 'chat_message.dart';

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAtEpochMs,
  });

  final String id;
  final String title;
  final List<ChatMessage> messages;
  final int updatedAtEpochMs;

  ChatConversation copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    int? updatedAtEpochMs,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'updatedAtEpochMs': updatedAtEpochMs,
        'messages': messages.map((message) => message.toJson()).toList(growable: false),
      };

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
      messages: rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map(
                (item) => ChatMessage.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const <ChatMessage>[],
    );
  }
}
