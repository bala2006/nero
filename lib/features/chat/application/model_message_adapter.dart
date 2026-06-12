import '../domain/chat_message.dart';

class ModelMessageAdapter {
  const ModelMessageAdapter();

  ChatMessage adapt(ChatMessage message) {
    if (message.role != ChatRole.user || message.attachments.isEmpty) {
      return message;
    }
    final attachmentSummary = message.attachments
        .map((attachment) {
          final context = attachment.contextText?.trim();
          if (context == null || context.isEmpty) {
            return '- ${attachment.title} (${attachment.kindLabel})';
          }
          return '- ${attachment.title} (${attachment.kindLabel})\n  Extracted context: $context';
        })
        .join('\n');
    return message.copyWith(
      content:
          'Attached files:\n$attachmentSummary\n\nUser request:\n${message.content}',
    );
  }
}
