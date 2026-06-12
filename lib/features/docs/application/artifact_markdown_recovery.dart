class ArtifactMarkdownRecovery {
  const ArtifactMarkdownRecovery();

  String? sanitizeMarkdown(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final embeddedMarkdown = _extractEmbeddedArtifactMarkdown(trimmed);
    if (embeddedMarkdown != null) {
      return embeddedMarkdown;
    }
    if (_looksLikeArtifactImplementationCode(trimmed)) {
      return null;
    }
    // We only reject planning text if it TRULY lacks any document structure.
    if (_looksLikeArtifactPlanningText(trimmed) &&
        !_looksStructuredLikeDocument(trimmed)) {
      return null;
    }
    var value = trimmed
        .replaceAll(RegExp(r'\[\[/?NERO_BLOCK:[^\]]+\]\]'), '')
        .replaceAll('[[/NERO_BLOCK]]', '')
        .replaceAll(RegExp(r'<\/?tool_call>[\s\S]*', caseSensitive: false), '')
        .trim();
    value = value.replaceAll(
      RegExp(r'```(?:python|dart|javascript|typescript)?', caseSensitive: false),
      '',
    );
    value = value.replaceAll('```', '').trim();
    value = _stripConversationalFiller(value);
    if (value.isEmpty) {
      return null;
    }
    final embeddedValueMarkdown = _extractEmbeddedArtifactMarkdown(value);
    if (embeddedValueMarkdown != null) {
      return embeddedValueMarkdown;
    }
    if (_looksLikeArtifactImplementationCode(value)) {
      return null;
    }
    if (_looksLikeArtifactPlanningText(value)) {
      return null;
    }
    if (_looksLikeArtifactPromiseOnly(value) &&
        !_looksStructuredLikeDocument(value)) {
      return null;
    }
    return value;
  }

  String resolveTitle({
    required String proposedTitle,
    required String prompt,
    required String markdownContent,
  }) {
    final bestEffort = _bestEffortArtifactTitle(
      prompt: prompt,
      markdownContent: markdownContent,
    );
    final trimmedTitle = proposedTitle.trim();
    if (trimmedTitle.isEmpty) {
      return bestEffort;
    }
    final normalizedPromptTitle = _bestEffortDocTitle(prompt).toLowerCase();
    final normalizedTitle = trimmedTitle.toLowerCase();
    if (normalizedTitle == 'nero document' ||
        normalizedTitle == 'nero pdf' ||
        normalizedTitle == normalizedPromptTitle ||
        _looksLikePromptStyleArtifactTitle(trimmedTitle) ||
        _looksLikeArtifactPlanningText(trimmedTitle) ||
        _looksLikeArtifactPromiseOnly(trimmedTitle)) {
      return bestEffort;
    }
    return trimmedTitle;
  }

  String _bestEffortArtifactTitle({
    required String prompt,
    required String markdownContent,
  }) {
    final heading = _firstMarkdownHeading(markdownContent);
    if (heading != null && heading.trim().isNotEmpty) {
      return heading.trim();
    }
    return _bestEffortDocTitle(prompt);
  }

  String _bestEffortDocTitle(String prompt) {
    final normalized = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return 'Nero Document';
    }
    if (normalized.length <= 80) {
      return normalized;
    }
    return '${normalized.substring(0, 80).trim()}...';
  }

  String? _firstMarkdownHeading(String markdownContent) {
    for (final line in markdownContent.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('#')) {
        continue;
      }
      final heading = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      if (heading.isNotEmpty) {
        return heading;
      }
    }
    return null;
  }

  bool _looksLikeArtifactPromiseOnly(String response) {
    final lowered = response.toLowerCase();
    final promises = RegExp(
      r"\b(?:i(?:'ll| will| am going to)|let me|i can create|i can generate|i will create|i will generate)\b",
      caseSensitive: false,
    ).hasMatch(lowered);
    final completions = RegExp(
      r'\b(?:created|generated|attached|saved|delivered|ready|completed)\b',
      caseSensitive: false,
    ).hasMatch(lowered);
    return promises && !completions;
  }

  bool _looksLikeArtifactImplementationCode(String response) {
    final lowered = response.toLowerCase();
    final mentionsDocLib =
        lowered.contains('from docx import') ||
        lowered.contains('import docx') ||
        lowered.contains('document()') ||
        lowered.contains('python-docx') ||
        lowered.contains('wd_paragraph_alignment') ||
        lowered.contains('oxmlelement') ||
        lowered.contains('from docx.shared import') ||
        lowered.contains('from docx.enum.text import');
    final mentionsArtifactCode =
        lowered.contains('generate_docx(') ||
        lowered.contains('generate_report_pdf(') ||
        lowered.contains('markdown_content=') ||
        lowered.contains('def create_') ||
        lowered.contains('def generate_');
    final fencedPython = lowered.contains('```python');
    return mentionsDocLib || (mentionsArtifactCode && fencedPython);
  }

  bool _looksLikeArtifactPlanningText(String response) {
    final lowered = response.toLowerCase();
    final planningPhrase =
        lowered.contains('we need to call generate_docx') ||
        lowered.contains('we need to call generate_report_pdf') ||
        lowered.contains('call generate_docx') ||
        lowered.contains('call generate_report_pdf') ||
        lowered.contains('must call generate_docx') ||
        lowered.contains('must call generate_report_pdf') ||
        lowered.contains('tool calling failed') ||
        lowered.contains('generate markdown_content') ||
        lowered.contains('with title and markdown_content');
    return planningPhrase;
  }

  String _stripConversationalFiller(String content) {
    var lines = content.split('\n');
    var resultIndex = 0;
    // Strip leading lines that look like "Sure! Here is your document:"
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#') ||
          line.startsWith('- ') ||
          line.startsWith('| ') ||
          line.startsWith('1. ')) {
        resultIndex = i;
        break;
      }
      // If we see a known planning/conversational phrase, we definitely skip it
      if (line.toLowerCase().contains('here is') ||
          line.toLowerCase().contains('certainly') ||
          line.toLowerCase().contains('document') ||
          line.toLowerCase().contains('file')) {
        continue;
      }
      // If we see general text and haven't hit a heading yet, it's likely filler
      // but we stop if it's too long (might be the document body starting)
    }
    return lines.sublist(resultIndex).join('\n').trim();
  }

  bool _looksStructuredLikeDocument(String value) {
    final trimmed = value.trimLeft();
    return trimmed.startsWith('#') ||
        trimmed.startsWith('- ') ||
        trimmed.startsWith('1. ') ||
        trimmed.contains('\n# ') ||
        trimmed.contains('\n## ') ||
        trimmed.contains('\n- ') ||
        trimmed.contains('\n1. ') ||
        trimmed.contains('| ');
  }

  bool _looksLikePromptStyleArtifactTitle(String value) {
    final lowered = value.trim().toLowerCase();
    return lowered.startsWith('generate ') ||
        lowered.startsWith('create ') ||
        lowered.startsWith('make ') ||
        lowered.startsWith('write ') ||
        lowered.startsWith('i want ') ||
        lowered.startsWith('can you ');
  }

  String? _extractEmbeddedArtifactMarkdown(String value) {
    final match = RegExp(
      "markdown_content\\s*=\\s*(?:\"\"\"([\\s\\S]*?)\"\"\"|'''([\\s\\S]*?)'''|\"([\\s\\S]*?)\"|'([\\s\\S]*?)')",
      caseSensitive: false,
    ).firstMatch(value);
    final extracted =
        match?.group(1) ?? match?.group(2) ?? match?.group(3) ?? match?.group(4);
    if (extracted == null) {
      return null;
    }
    final normalized = extracted
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', '\t')
        .trim();
    if (normalized.isEmpty || !_looksStructuredLikeDocument(normalized)) {
      return null;
    }
    return normalized;
  }
}
