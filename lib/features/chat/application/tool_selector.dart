import 'dart:async';
import 'dart:convert';

import '../domain/chat_message.dart';
import 'sarvam_api_client.dart';
import '../../capabilities/capabilities.dart';
import '../../capabilities/application/capability_catalog.dart';
import '../../runtime/application/request_classifier.dart';
import '../../runtime/domain/request_classification.dart';

class ToolSelectionDecision {
  const ToolSelectionDecision({
    required this.classification,
    required this.selectedTools,
    required this.strategy,
    this.strategyDetails = const <String, Object?>{},
  });

  final RequestClassification classification;
  final List<String> selectedTools;
  final String strategy;
  final Map<String, Object?> strategyDetails;

  RequestKind get requestKind => classification.requestKind;
  ArtifactKind get artifactKind => classification.artifactKind;
  bool get requiresExternalContext => classification.requiresExternalContext;
  bool get requiresSideEffect => classification.requiresSideEffect;
  bool get expectsArtifact => classification.artifactKind != ArtifactKind.none;
  double get confidence => classification.confidence;
  String get rationale => classification.reason;
  FinalAnswerMode get finalAnswerMode => classification.finalAnswerMode;
  FallbackPolicy get fallbackPolicy => classification.fallbackPolicy;

  Map<String, Object?> toDebugMetadata() {
    return <String, Object?>{
      'request_kind': requestKind.name,
      'artifact_kind': artifactKind.name,
      'selected_tools': selectedTools,
      'requires_external_context': requiresExternalContext,
      'requires_side_effect': requiresSideEffect,
      'expects_artifact': expectsArtifact,
      'confidence': confidence,
      'final_answer_mode': finalAnswerMode.name,
      'fallback_policy': fallbackPolicy.name,
      'strategy': strategy,
      'strategy_details': strategyDetails,
      'rationale': rationale,
    };
  }
}

class ToolSelector {
  ToolSelector({
    required ChatCompletionClient client,
    Duration timeout = const Duration(milliseconds: 1500),
    RequestClassifier requestClassifier = const RequestClassifier(),
    CapabilityCatalog? capabilityCatalog,
  }) : _client = client,
       _timeout = timeout,
       _requestClassifier = requestClassifier,
       _catalog = capabilityCatalog ?? CapabilityCatalog.instance;

  final ChatCompletionClient _client;
  final Duration _timeout;
  final RequestClassifier _requestClassifier;

  /// Source of the model's tool list. Read through [_refreshCatalog] so tools
  /// added at runtime (MCP, sandbox) are selectable on the next turn.
  final CapabilityCatalog _catalog;
  final Map<String, _ToolSelectionCacheEntry> _cache =
      <String, _ToolSelectionCacheEntry>{};

  int _catalogRevision = -1;
  Set<String> _modelToolNames = const <String>{};
  List<Map<String, Object?>> _modelToolPayloads = const <Map<String, Object?>>[];

  /// Rebuilds the cached tool list when the catalog changed and drops the
  /// selector cache, since a now-available tool could change a past decision.
  void _refreshCatalog() {
    if (_catalog.revision == _catalogRevision) {
      return;
    }
    _catalogRevision = _catalog.revision;
    _modelToolNames = _catalog.modelToolNames().toSet();
    _modelToolPayloads = _catalog.modelToolPayloads();
    _cache.clear();
  }

  Future<List<String>> selectTools({
    required String apiKey,
    required String prompt,
    required List<ChatMessage> recentMessages,
  }) async {
    final decision = await selectDecision(
      apiKey: apiKey,
      prompt: prompt,
      recentMessages: recentMessages,
    );
    return decision.selectedTools;
  }

  Future<ToolSelectionDecision> selectDecision({
    required String apiKey,
    required String prompt,
    required List<ChatMessage> recentMessages,
  }) async {
    _refreshCatalog();
    final cacheKey = _cacheKey(prompt: prompt, recentMessages: recentMessages);
    final cached = _cache[cacheKey];
    final now = DateTime.now();
    if (cached != null &&
        now.difference(cached.createdAt) < const Duration(seconds: 30)) {
      return ToolSelectionDecision(
        classification: _requestClassifier.classify(prompt),
        selectedTools: cached.tools,
        strategy: 'cache',
        strategyDetails: <String, Object?>{
          'cache_hit': true,
          'cached_tools': cached.tools,
        },
      );
    }
    final classification = _requestClassifier.classify(prompt);
    if (classification.isArtifactCapabilityQuestion) {
      return ToolSelectionDecision(
        classification: classification,
        selectedTools: const <String>[],
        strategy: 'classification_only',
        strategyDetails: <String, Object?>{
          'cache_hit': false,
          'classification_gate': 'artifact_capability_question',
          'suppressed_tools': _modelToolNames.where(_isArtifactTool).toList(
            growable: false,
          ),
        },
      );
    }

    try {
      final context = recentMessages
          .take(2)
          .map(
            (message) =>
                '[${message.role.name}: ${message.content.replaceAll('\n', ' ').trim()}]',
          )
          .join('\n');
      final result = await _client
          .completeChat(
            apiKey: apiKey,
            modelId: 'sarvam-m',
            messages: <ChatMessage>[
              const ChatMessage(
                id: 'tool_selector_system',
                role: ChatRole.system,
                content:
                    'You are a tool selector. Given recent conversation and a new user message, output ONLY a JSON array of tool names that are necessary. '
                    'Output [] if no tools are needed. No explanation, no prose.\n'
                    'Examples:\n'
                    'Q: "What is recursion?" -> []\n'
                    'Q: "Latest news on AI today" -> ["search_web"]\n'
                    'Q: "Summarize https://flutter.dev/docs" -> ["read_url"]\n'
                    'Q: "Extract this article: https://medium.com/..." -> ["extract_article"]\n'
                    'Q: "Write a project proposal Word doc" -> ["generate_docx"]\n'
                    'Q: "Make an expense tracker spreadsheet" -> ["generate_xlsx"]\n'
                    'Q: "Create a PDF report for this summary" -> ["generate_report_pdf"]\n'
                    'Q: "Research Flutter CI and create a report" -> ["search_web", "generate_docx"]\n'
                    'Q: "Create a README.md file" -> ["create_text_file"]\n'
                    'Q: "Build a Python project with main.py and requirements.txt" -> ["write_project_files"]\n'
                    'Q: "Create project files and give me a zip" -> ["write_project_files", "package_zip"]\n'
                    'Q: "Make a todo list text file" -> ["create_text_file"]',
              ),
              ChatMessage(
                id: 'tool_selector_user',
                role: ChatRole.user,
                content:
                    'Recent conversation:\n$context\n\nCurrent user message:\n$prompt\n\nAvailable tools:\n${jsonEncode(_modelToolPayloads)}',
              ),
            ],
          )
          .timeout(_timeout);
      final parsed = _parseSelection(result.content, prompt: prompt);
      final merged = _mergeWithMandatoryHeuristics(
        parsed.selectedTools,
        prompt: prompt,
        classification: classification,
      );
      final selected = merged.selectedTools;
      _cache[cacheKey] = _ToolSelectionCacheEntry(
        tools: selected,
        createdAt: now,
      );
      return ToolSelectionDecision(
        classification: classification,
        selectedTools: selected,
        strategy: 'model_plus_classifier',
        strategyDetails: <String, Object?>{
          'cache_hit': false,
          'selector_response_kind': parsed.responseKind,
          'model_selected_tools': parsed.selectedTools,
          'mandatory_added_tools': merged.mandatoryAddedTools,
          'heuristic_added_tools': merged.heuristicAddedTools,
          'suppressed_tools': merged.suppressedTools,
        },
      );
    } catch (_) {
      final selected = _heuristicFallbackTools(
        prompt,
        classification: classification,
      );
      return ToolSelectionDecision(
        classification: classification,
        selectedTools: selected,
        strategy: 'classifier_fallback',
        strategyDetails: <String, Object?>{
          'cache_hit': false,
          'selector_response_kind': 'exception_fallback',
          'heuristic_selected_tools': selected,
        },
      );
    }
  }

  _ParsedSelection _parseSelection(String raw, {required String prompt}) {
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! List) {
        return _ParsedSelection(
          selectedTools: _heuristicFallbackTools(prompt),
          responseKind: 'non_list_json_fallback',
        );
      }
      if (decoded.isEmpty) {
        return const _ParsedSelection(
          selectedTools: <String>[],
          responseKind: 'explicit_empty',
        );
      }
      final selected = decoded
          .map((item) => item.toString().trim())
          .where(_modelToolNames.contains)
          .toSet()
          .toList(growable: false);
      return selected.isEmpty
          ? _ParsedSelection(
              selectedTools: _heuristicFallbackTools(prompt),
              responseKind: 'unknown_tool_names_fallback',
            )
          : _ParsedSelection(
              selectedTools: selected,
              responseKind: 'model_json_array',
            );
    } catch (_) {
      return _ParsedSelection(
        selectedTools: _heuristicFallbackTools(prompt),
        responseKind: 'parse_error_fallback',
      );
    }
  }

  List<String> _heuristicFallbackTools(
    String prompt, {
    RequestClassification? classification,
  }) {
    final lowered = prompt.toLowerCase();
    final effectiveClassification = classification ?? _requestClassifier.classify(prompt);
    if (effectiveClassification.isArtifactCapabilityQuestion) {
      return const <String>[];
    }
    final selected = <String>{};
    final needsWeb = effectiveClassification.requiresExternalContext;
    if (needsWeb) {
      selected.add('search_web');
    }
    if (lowered.contains('summarize http') ||
        lowered.contains('read http') ||
        RegExp(r'https?://').hasMatch(lowered)) {
      selected.add('read_url');
    }
    if (lowered.contains('article')) {
      selected.add('extract_article');
    }
    if (effectiveClassification.artifactKind == ArtifactKind.xlsx) {
      selected.add('generate_xlsx');
    } else if (effectiveClassification.artifactKind == ArtifactKind.pdf) {
      selected.add('generate_report_pdf');
    } else if (effectiveClassification.artifactKind == ArtifactKind.docx) {
      selected.add('generate_docx');
    }

    if (_looksLikeFileCreationRequest(lowered)) {
      selected.add('create_text_file');
    }
    if (_looksLikeProjectCreationRequest(lowered)) {
      selected.add('write_project_files');
    }
    if (_looksLikeZipRequest(lowered)) {
      selected.add('package_zip');
    }

    return selected.isEmpty ? const <String>[] : selected.toList(growable: false);
  }

  _MergedSelection _mergeWithMandatoryHeuristics(
    List<String> selectedTools, {
    required String prompt,
    required RequestClassification classification,
  }) {
    final lowered = prompt.toLowerCase();
    final originalSet = selectedTools.toSet();
    final merged = <String>{
      ...selectedTools.where(
        (tool) => !classification.isArtifactCapabilityQuestion ||
            !_isArtifactTool(tool),
      ),
    };
    final suppressedTools = selectedTools
        .where(
          (tool) => classification.isArtifactCapabilityQuestion &&
              _isArtifactTool(tool),
        )
        .toSet()
        .toList(growable: false);

    if (classification.isArtifactCapabilityQuestion) {
      return _MergedSelection(
        selectedTools: merged.isEmpty
            ? const <String>[]
            : merged.toList(growable: false),
        mandatoryAddedTools: const <String>[],
        heuristicAddedTools: const <String>[],
        suppressedTools: suppressedTools,
      );
    }

    if (classification.artifactKind == ArtifactKind.docx) {
      merged.add('generate_docx');
    }
    if (classification.artifactKind == ArtifactKind.xlsx) {
      merged.add('generate_xlsx');
    }
    if (classification.artifactKind == ArtifactKind.pdf) {
      merged.add('generate_report_pdf');
    }
    if (_looksLikeProjectCreationRequest(lowered)) {
      merged.add('write_project_files');
    }
    if (_looksLikeFileCreationRequest(lowered)) {
      merged.add('create_text_file');
    }
    if (_looksLikeZipRequest(lowered)) {
      merged.add('package_zip');
    }
    if (classification.requiresExternalContext || _looksLikeWebRequest(lowered)) {
      merged.add('search_web');
    }
    if (lowered.contains('summarize http') ||
        lowered.contains('read http') ||
        RegExp(r'https?://').hasMatch(lowered)) {
      merged.add('read_url');
    }
    if (lowered.contains('article')) {
      merged.add('extract_article');
    }

    final mandatoryAddedTools = <String>[
      if (classification.artifactKind == ArtifactKind.docx &&
          !originalSet.contains('generate_docx'))
        'generate_docx',
      if (classification.artifactKind == ArtifactKind.xlsx &&
          !originalSet.contains('generate_xlsx'))
        'generate_xlsx',
      if (classification.artifactKind == ArtifactKind.pdf &&
          !originalSet.contains('generate_report_pdf'))
        'generate_report_pdf',
    ];
    final heuristicAddedTools = merged
        .difference(originalSet)
        .where((tool) => !mandatoryAddedTools.contains(tool))
        .toList(growable: false);

    return _MergedSelection(
      selectedTools: merged.isEmpty
          ? const <String>[]
          : merged.toList(growable: false),
      mandatoryAddedTools: mandatoryAddedTools,
      heuristicAddedTools: heuristicAddedTools,
      suppressedTools: suppressedTools,
    );
  }

  bool _looksLikeWebRequest(String prompt) {
    return prompt.contains('latest') ||
        prompt.contains('today') ||
        prompt.contains('current') ||
        prompt.contains('news') ||
        prompt.contains('search') ||
        prompt.contains('browse') ||
        prompt.contains('web') ||
        prompt.contains('url') ||
        prompt.contains('link');
  }

  String _cacheKey({
    required String prompt,
    required List<ChatMessage> recentMessages,
  }) {
    final buffer = StringBuffer(prompt.trim());
    for (final message in recentMessages.take(2)) {
      buffer
        ..write('|')
        ..write(message.role.name)
        ..write(':')
        ..write(message.content.trim());
    }
    return buffer.toString();
  }

  bool _looksLikeFileCreationRequest(String prompt) {
    final asksToCreate = _asksForArtifact(prompt);
    final namesFile =
        prompt.contains('.txt') ||
        prompt.contains('.md') ||
        prompt.contains('.py') ||
        prompt.contains('.js') ||
        prompt.contains('.json') ||
        prompt.contains('.csv') ||
        prompt.contains('.html') ||
        prompt.contains('.yaml') ||
        prompt.contains('text file') ||
        prompt.contains('readme') ||
        prompt.contains('notes file') ||
        prompt.contains('config file');
    return asksToCreate && namesFile;
  }

  bool _looksLikeProjectCreationRequest(String prompt) {
    final asksToCreate = _asksForArtifact(prompt) || prompt.contains('scaffold');
    final namesProject =
        prompt.contains('project') ||
        prompt.contains('boilerplate') ||
        prompt.contains('starter') ||
        prompt.contains('template') ||
        (prompt.contains('multiple') && prompt.contains('file'));
    return asksToCreate && namesProject;
  }

  bool _looksLikeZipRequest(String prompt) {
    return prompt.contains('zip') ||
        prompt.contains('archive') ||
        prompt.contains('bundle') ||
        (prompt.contains('download') && prompt.contains('file'));
  }

  bool _isArtifactTool(String toolName) {
    return toolName == 'generate_docx' ||
        toolName == 'generate_xlsx' ||
        toolName == 'generate_report_pdf';
  }

  bool _asksForArtifact(String prompt) {
    return prompt.contains('create') ||
        prompt.contains('generate') ||
        prompt.contains('make') ||
        prompt.contains('prepare') ||
        prompt.contains('write') ||
        prompt.contains('build') ||
        prompt.contains('export') ||
        prompt.contains('i want') ||
        prompt.contains('i need') ||
        prompt.contains('want a') ||
        prompt.contains('need a') ||
        prompt.contains('want an') ||
        prompt.contains('need an') ||
        prompt.contains('give me') ||
        prompt.contains('provide a') ||
        prompt.contains('provide an');
  }
}

class _ToolSelectionCacheEntry {
  const _ToolSelectionCacheEntry({
    required this.tools,
    required this.createdAt,
  });

  final List<String> tools;
  final DateTime createdAt;
}

class _ParsedSelection {
  const _ParsedSelection({
    required this.selectedTools,
    required this.responseKind,
  });

  final List<String> selectedTools;
  final String responseKind;
}

class _MergedSelection {
  const _MergedSelection({
    required this.selectedTools,
    required this.mandatoryAddedTools,
    required this.heuristicAddedTools,
    required this.suppressedTools,
  });

  final List<String> selectedTools;
  final List<String> mandatoryAddedTools;
  final List<String> heuristicAddedTools;
  final List<String> suppressedTools;
}
