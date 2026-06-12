enum ChatRole { user, assistant, system }

ChatRole _chatRoleFromJson(String? value) {
  return switch (value) {
    'user' => ChatRole.user,
    'assistant' => ChatRole.assistant,
    'system' => ChatRole.system,
    _ => ChatRole.user,
  };
}

String _chatRoleToJson(ChatRole role) {
  return switch (role) {
    ChatRole.user => 'user',
    ChatRole.assistant => 'assistant',
    ChatRole.system => 'system',
  };
}

enum ChatActivityType {
  thought,
  agentPlan,
  webSearch,
  pageRead,
  articleExtract,
}

ChatActivityType _chatActivityTypeFromJson(String? value) {
  return switch (value) {
    'thought' => ChatActivityType.thought,
    'agentPlan' => ChatActivityType.agentPlan,
    'webSearch' => ChatActivityType.webSearch,
    'pageRead' => ChatActivityType.pageRead,
    'articleExtract' => ChatActivityType.articleExtract,
    _ => ChatActivityType.thought,
  };
}

String _chatActivityTypeToJson(ChatActivityType type) {
  return switch (type) {
    ChatActivityType.thought => 'thought',
    ChatActivityType.agentPlan => 'agentPlan',
    ChatActivityType.webSearch => 'webSearch',
    ChatActivityType.pageRead => 'pageRead',
    ChatActivityType.articleExtract => 'articleExtract',
  };
}

class ChatActivityItem {
  const ChatActivityItem({
    required this.title,
    this.subtitle,
    this.trailing,
    this.url,
    this.state,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final String? url;
  final String? state;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'subtitle': subtitle,
    'trailing': trailing,
    'url': url,
    'state': state,
  };

  factory ChatActivityItem.fromJson(Map<String, dynamic> json) {
    return ChatActivityItem(
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      trailing: json['trailing']?.toString(),
      url: json['url']?.toString(),
      state: json['state']?.toString(),
    );
  }
}

class ChatActivity {
  const ChatActivity({
    required this.type,
    required this.title,
    this.subtitle,
    this.items = const <ChatActivityItem>[],
    this.isComplete = false,
  });

  final ChatActivityType type;
  final String title;
  final String? subtitle;
  final List<ChatActivityItem> items;
  final bool isComplete;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': _chatActivityTypeToJson(type),
    'title': title,
    'subtitle': subtitle,
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'isComplete': isComplete,
  };

  factory ChatActivity.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ChatActivity(
      type: _chatActivityTypeFromJson(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => ChatActivityItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <ChatActivityItem>[],
      isComplete: json['isComplete'] == true,
    );
  }
}

class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.title,
    required this.kindLabel,
    this.extension,
    this.contextText,
  });

  final String id;
  final String title;
  final String kindLabel;
  final String? extension;
  final String? contextText;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'kindLabel': kindLabel,
    'extension': extension,
    'contextText': contextText,
  };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      kindLabel: json['kindLabel']?.toString() ?? 'File',
      extension: json['extension']?.toString(),
      contextText: json['contextText']?.toString(),
    );
  }
}

class GeneratedArtifactReference {
  const GeneratedArtifactReference({
    required this.id,
    required this.title,
    required this.kindLabel,
    this.extension,
    this.mimeType,
    this.localPath,
    this.sourceUri,
    this.sizeBytes,
    this.previewMarkdown,
  });

  final String id;
  final String title;
  final String kindLabel;
  final String? extension;
  final String? mimeType;
  final String? localPath;
  final String? sourceUri;
  final int? sizeBytes;
  final String? previewMarkdown;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'kindLabel': kindLabel,
    'extension': extension,
    'mimeType': mimeType,
    'localPath': localPath,
    'sourceUri': sourceUri,
    'sizeBytes': sizeBytes,
    'previewMarkdown': previewMarkdown,
  };

  factory GeneratedArtifactReference.fromJson(Map<String, dynamic> json) {
    return GeneratedArtifactReference(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      kindLabel: json['kindLabel']?.toString() ?? 'Artifact',
      extension: json['extension']?.toString(),
      mimeType: json['mimeType']?.toString(),
      localPath: json['localPath']?.toString(),
      sourceUri: json['sourceUri']?.toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      previewMarkdown: json['previewMarkdown']?.toString(),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.sentAtEpochMs,
    this.isStreaming = false,
    this.tokensPerSecond,
    this.averageTokensPerSecond,
    this.thinkingSteps = const <String>[],
    this.thinkingDurationMs,
    this.thinkingStartedAtEpochMs,
    this.activities = const <ChatActivity>[],
    this.attachments = const <ChatAttachment>[],
    this.generatedArtifacts = const <GeneratedArtifactReference>[],
  });

  final String id;
  final ChatRole role;
  final String content;
  final int? sentAtEpochMs;
  final bool isStreaming;
  final double? tokensPerSecond;
  final double? averageTokensPerSecond;
  final List<String> thinkingSteps;
  final int? thinkingDurationMs;
  final int? thinkingStartedAtEpochMs;
  final List<ChatActivity> activities;
  final List<ChatAttachment> attachments;
  final List<GeneratedArtifactReference> generatedArtifacts;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'role': _chatRoleToJson(role),
    'content': content,
    'sentAtEpochMs': sentAtEpochMs,
    'isStreaming': isStreaming,
    'tokensPerSecond': tokensPerSecond,
    'averageTokensPerSecond': averageTokensPerSecond,
    'thinkingSteps': thinkingSteps,
    'thinkingDurationMs': thinkingDurationMs,
    'thinkingStartedAtEpochMs': thinkingStartedAtEpochMs,
    'activities': activities
        .map((item) => item.toJson())
        .toList(growable: false),
    'attachments': attachments
        .map((item) => item.toJson())
        .toList(growable: false),
    'generatedArtifacts': generatedArtifacts
        .map((item) => item.toJson())
        .toList(growable: false),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawThinkingSteps = json['thinkingSteps'];
    final rawActivities = json['activities'];
    final rawAttachments = json['attachments'];
    final rawGeneratedArtifacts = json['generatedArtifacts'];
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      role: _chatRoleFromJson(json['role']?.toString()),
      content: json['content']?.toString() ?? '',
      sentAtEpochMs: (json['sentAtEpochMs'] as num?)?.toInt(),
      isStreaming: json['isStreaming'] == true,
      tokensPerSecond: (json['tokensPerSecond'] as num?)?.toDouble(),
      averageTokensPerSecond: (json['averageTokensPerSecond'] as num?)
          ?.toDouble(),
      thinkingSteps: rawThinkingSteps is List
          ? rawThinkingSteps
                .map((item) => item.toString())
                .toList(growable: false)
          : const <String>[],
      thinkingDurationMs: (json['thinkingDurationMs'] as num?)?.toInt(),
      thinkingStartedAtEpochMs: (json['thinkingStartedAtEpochMs'] as num?)
          ?.toInt(),
      activities: rawActivities is List
          ? rawActivities
                .whereType<Map>()
                .map(
                  (item) =>
                      ChatActivity.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <ChatActivity>[],
      attachments: rawAttachments is List
          ? rawAttachments
                .whereType<Map>()
                .map(
                  (item) =>
                      ChatAttachment.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <ChatAttachment>[],
      generatedArtifacts: rawGeneratedArtifacts is List
          ? rawGeneratedArtifacts
                .whereType<Map>()
                .map(
                  (item) => GeneratedArtifactReference.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <GeneratedArtifactReference>[],
    );
  }

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    int? sentAtEpochMs,
    bool? isStreaming,
    double? tokensPerSecond,
    double? averageTokensPerSecond,
    List<String>? thinkingSteps,
    int? thinkingDurationMs,
    int? thinkingStartedAtEpochMs,
    List<ChatActivity>? activities,
    List<ChatAttachment>? attachments,
    List<GeneratedArtifactReference>? generatedArtifacts,
    bool clearTokensPerSecond = false,
    bool clearAverageTokensPerSecond = false,
    bool clearThinkingDurationMs = false,
    bool clearThinkingStartedAtEpochMs = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      sentAtEpochMs: sentAtEpochMs ?? this.sentAtEpochMs,
      isStreaming: isStreaming ?? this.isStreaming,
      tokensPerSecond: clearTokensPerSecond
          ? null
          : tokensPerSecond ?? this.tokensPerSecond,
      averageTokensPerSecond: clearAverageTokensPerSecond
          ? null
          : averageTokensPerSecond ?? this.averageTokensPerSecond,
      thinkingSteps: thinkingSteps ?? this.thinkingSteps,
      thinkingDurationMs: clearThinkingDurationMs
          ? null
          : thinkingDurationMs ?? this.thinkingDurationMs,
      thinkingStartedAtEpochMs: clearThinkingStartedAtEpochMs
          ? null
          : thinkingStartedAtEpochMs ?? this.thinkingStartedAtEpochMs,
      activities: activities ?? this.activities,
      attachments: attachments ?? this.attachments,
      generatedArtifacts: generatedArtifacts ?? this.generatedArtifacts,
    );
  }
}
