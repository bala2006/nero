import '../../docs/application/artifact_request_policy.dart';

class TaskHintPolicy {
  const TaskHintPolicy({
    ArtifactRequestPolicy artifactRequestPolicy =
        const ArtifactRequestPolicy(),
  }) : _artifactRequestPolicy = artifactRequestPolicy;

  final ArtifactRequestPolicy _artifactRequestPolicy;

  String? buildHint(String prompt) {
    final lowered = prompt.toLowerCase();
    final hints = <String>[];

    if (lowered.contains('table') ||
        lowered.contains('markdown table') ||
        lowered.contains('tabular')) {
      hints.add(
        'Reply with a [[NERO_BLOCK:TABLE]] section containing a valid Markdown table, then close it with [[/NERO_BLOCK]]. Do not add extra narration unless asked.',
      );
    }

    if (lowered.contains('code') ||
        lowered.contains('function') ||
        lowered.contains('python') ||
        lowered.contains('dart') ||
        lowered.contains('flutter') ||
        lowered.contains('javascript') ||
        lowered.contains('typescript') ||
        lowered.contains('sql')) {
      hints.add(
        'Reply with a [[NERO_BLOCK:CODE lang=<language>]] section using the most relevant language, then close it with [[/NERO_BLOCK]]. Keep any explanation short and after the code block.',
      );
    }

    if (lowered.contains('diagram') ||
        lowered.contains('flowchart') ||
        lowered.contains('sequence diagram') ||
        lowered.contains('mermaid') ||
        lowered.contains('architecture diagram') ||
        lowered.contains('er diagram')) {
      hints.add(
        'Reply with one [[NERO_BLOCK:DIAGRAM lang=mermaid]] section and close it with [[/NERO_BLOCK]]. Do not wrap Mermaid syntax in another code block.',
      );
    }

    if ((lowered.contains('top ') ||
            lowered.contains('most') ||
            lowered.contains('list') ||
            lowered.contains('questions')) &&
        (lowered.contains('diagram') || lowered.contains('mermaid'))) {
      hints.add(
        'Because this is a multi-item answer, include only one simple Mermaid diagram for the overall workflow or concept summary, not one diagram per item.',
      );
    }

    if (lowered.contains('format') ||
        lowered.contains('markdown') ||
        lowered.contains('bullet') ||
        lowered.contains('heading') ||
        lowered.contains('summary')) {
      hints.add(
        'Use concise Markdown formatting with clear section headings and compact lists where useful.',
      );
    }

    if (_artifactRequestPolicy.looksLikeDocxRequest(lowered)) {
      hints.add(
        'The user wants a downloadable document file. Call the generate_docx tool with a clear title and markdown_content for the document body. Do not answer by only rendering the document in chat.',
      );
    }

    if (_artifactRequestPolicy.looksLikeSpreadsheetRequest(lowered)) {
      hints.add(
        'The user wants a downloadable spreadsheet file. Call the generate_xlsx tool with a clear title and a sheets array. Each sheet must include a name and rows as a 2D array of strings, numbers, booleans, or formulas starting with "=".',
      );
    }

    if (_artifactRequestPolicy.looksLikePdfRequest(lowered)) {
      hints.add(
        'The user wants a downloadable PDF file. Call the generate_report_pdf tool with a clear title and markdown_content for the PDF body. Do not answer by only rendering the PDF content in chat.',
      );
    }

    if (_looksLikeTextFileRequest(lowered)) {
      hints.add(
        'The user wants a text file created in the workspace. Call the create_text_file tool with a file_name (including extension) and the full content. You can call this tool multiple times for multiple files.',
      );
    }

    if (_looksLikeProjectRequest(lowered)) {
      hints.add(
        'The user wants a multi-file project. Call the write_project_files tool with a project_name and a files array. Each file needs a relative path and content. After creating the project, if the user wants a zip, call package_zip.',
      );
    }

    if (_looksLikeZipRequest(lowered)) {
      hints.add(
        'The user wants files bundled as a ZIP archive. After creating all needed files, call the package_zip tool with an archive_name to bundle them for download.',
      );
    }

    if (hints.isEmpty) {
      return null;
    }

    return hints.join('\n');
  }

  bool _looksLikeTextFileRequest(String loweredPrompt) {
    final asksToCreate = _asksForArtifact(loweredPrompt);
    final namesFile =
        loweredPrompt.contains('.txt') ||
        loweredPrompt.contains('.md') ||
        loweredPrompt.contains('.py') ||
        loweredPrompt.contains('.js') ||
        loweredPrompt.contains('.json') ||
        loweredPrompt.contains('.csv') ||
        loweredPrompt.contains('.html') ||
        loweredPrompt.contains('.yaml') ||
        loweredPrompt.contains('text file') ||
        loweredPrompt.contains('readme') ||
        loweredPrompt.contains('notes file') ||
        loweredPrompt.contains('config file');
    return asksToCreate && namesFile;
  }

  bool _looksLikeProjectRequest(String loweredPrompt) {
    final asksToCreate =
        _asksForArtifact(loweredPrompt) || loweredPrompt.contains('scaffold');
    final namesProject =
        loweredPrompt.contains('project') ||
        loweredPrompt.contains('boilerplate') ||
        loweredPrompt.contains('starter') ||
        loweredPrompt.contains('template') ||
        (loweredPrompt.contains('multiple') && loweredPrompt.contains('file'));
    return asksToCreate && namesProject;
  }

  bool _looksLikeZipRequest(String loweredPrompt) {
    return loweredPrompt.contains('zip') ||
        loweredPrompt.contains('archive') ||
        loweredPrompt.contains('bundle');
  }

  bool _asksForArtifact(String loweredPrompt) {
    return loweredPrompt.contains('create') ||
        loweredPrompt.contains('generate') ||
        loweredPrompt.contains('make') ||
        loweredPrompt.contains('prepare') ||
        loweredPrompt.contains('write') ||
        loweredPrompt.contains('build') ||
        loweredPrompt.contains('export') ||
        loweredPrompt.contains('i want') ||
        loweredPrompt.contains('i need') ||
        loweredPrompt.contains('want a') ||
        loweredPrompt.contains('need a') ||
        loweredPrompt.contains('want an') ||
        loweredPrompt.contains('need an') ||
        loweredPrompt.contains('give me') ||
        loweredPrompt.contains('provide a') ||
        loweredPrompt.contains('provide an');
  }
}
