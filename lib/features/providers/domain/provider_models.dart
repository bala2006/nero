class ProviderDescriptor {
  const ProviderDescriptor({
    required this.providerId,
    required this.displayName,
    required this.supportsStreaming,
    required this.supportsToolCalling,
  });

  final String providerId;
  final String displayName;
  final bool supportsStreaming;
  final bool supportsToolCalling;
}

class ProviderToolDefinition {
  const ProviderToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;
}

class ProviderToolCall {
  const ProviderToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;
}

class ProviderCompletionResult {
  const ProviderCompletionResult({
    required this.content,
    required this.model,
    this.reasoningContent,
    this.toolCalls = const <ProviderToolCall>[],
    this.finishReason,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  final String content;
  final String model;
  final String? reasoningContent;
  final List<ProviderToolCall> toolCalls;
  final String? finishReason;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
}
