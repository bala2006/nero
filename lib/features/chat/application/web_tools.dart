import 'dart:async';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class ToolExecutionResult {
  const ToolExecutionResult({
    required this.success,
    required this.summary,
    required this.formattedOutput,
    this.items = const <ToolExecutionItem>[],
    this.query,
    this.url,
  });

  final bool success;
  final String summary;
  final String formattedOutput;
  final List<ToolExecutionItem> items;
  final String? query;
  final String? url;
}

class ToolExecutionItem {
  const ToolExecutionItem({
    required this.title,
    this.subtitle,
    this.trailing,
    this.url,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final String? url;
}

class WebToolService {
  static const String _userAgent = 'Mozilla/5.0 (compatible; Nero/1.0)';
  static const Duration _timeout = Duration(seconds: 12);

  Future<ToolExecutionResult> searchWeb({
    required String query,
    int limit = 5,
  }) async {
    try {
      final attempts = <String>[
        query.trim(),
        _simplifySearchQuery(query),
      ].where((item) => item.isNotEmpty).toSet().toList(growable: false);

      var results = <Map<String, String>>[];
      for (final attempt in attempts) {
        results = await _searchDuckDuckGo(attempt, limit: limit);
        if (results.isNotEmpty) {
          break;
        }
      }

      if (results.isEmpty) {
        return ToolExecutionResult(
          success: false,
          summary: 'No results found for "$query".',
          formattedOutput:
              'I searched for "$query" but could not find relevant results.',
          query: query,
        );
      }

      final buffer = StringBuffer()..writeln('### Search Results: "$query"\n');
      for (final result in results) {
        final title = result['title']!;
        final snippet = result['snippet']!;
        final link = result['url']!;
        buffer.writeln(link.isNotEmpty ? '- [$title]($link)' : '- $title');
        if (snippet.isNotEmpty) {
          buffer.writeln('  - $snippet');
        }
      }

      return ToolExecutionResult(
        success: true,
        summary: 'Found ${results.length} result(s) for "$query".',
        formattedOutput: buffer.toString().trim(),
        query: query,
        items: [
          for (final result in results)
            ToolExecutionItem(
              title: result['title'] ?? '',
              subtitle: result['snippet']?.isNotEmpty == true
                  ? result['snippet']
                  : null,
              trailing: _hostnameFromUrl(result['url']),
              url: result['url']?.isNotEmpty == true ? result['url'] : null,
            ),
        ],
      );
    } on TimeoutException {
      return const ToolExecutionResult(
        success: false,
        summary: 'Web search timed out.',
        formattedOutput: 'Search request timed out. Try a simpler query.',
      );
    } catch (error) {
      return ToolExecutionResult(
        success: false,
        summary: 'Web search failed.',
        formattedOutput: 'Search failed: $error',
      );
    }
  }

  Future<ToolExecutionResult> readUrl(String url) async {
    try {
      final document = await _fetchDocument(url);
      final title = _extractTitle(document);
      final content = _extractMainContent(document);
      final summary = _generateSummary(content);
      return ToolExecutionResult(
        success: true,
        summary: 'Read page "$title".',
        url: url,
        items: [
          ToolExecutionItem(
            title: title,
            subtitle: summary,
            trailing: _hostnameFromUrl(url),
            url: url,
          ),
        ],
        formattedOutput: '''
### Page Content: $title
**Source:** [$url]($url)

**Summary**
> $summary

**Excerpt**
${content.length > 1200 ? '${content.substring(0, 1200)}...\n\n*(Content truncated)*' : content}
'''.trim(),
      );
    } on TimeoutException {
      return const ToolExecutionResult(
        success: false,
        summary: 'URL read timed out.',
        formattedOutput: 'Timed out while reading the page.',
      );
    } catch (error) {
      return ToolExecutionResult(
        success: false,
        summary: 'URL read failed.',
        formattedOutput: 'Failed to read URL: $error',
      );
    }
  }

  Future<ToolExecutionResult> extractArticle(String url) async {
    try {
      final document = await _fetchDocument(url);
      final title = _extractTitle(document);
      final author = _extractAuthor(document);
      final publishDate = _extractPublishDate(document);
      final content = _extractArticleContent(document);
      final summary = _generateSummary(content);

      final buffer = StringBuffer()
        ..writeln('### Article: $title')
        ..writeln('**Source:** [$url]($url)');
      if (author != null && author.isNotEmpty) {
        buffer.writeln('**Author:** $author');
      }
      if (publishDate != null && publishDate.isNotEmpty) {
        buffer.writeln('**Published:** $publishDate');
      }
      buffer
        ..writeln('\n**Summary**')
        ..writeln('> $summary')
        ..writeln('\n**Content**')
        ..writeln(
          content.length > 2000
              ? '${content.substring(0, 2000)}...\n\n*(Article truncated)*'
              : content,
        );

      return ToolExecutionResult(
        success: true,
        summary: 'Extracted article "$title".',
        url: url,
        items: [
          ToolExecutionItem(
            title: title,
            subtitle: summary,
            trailing: _hostnameFromUrl(url),
            url: url,
          ),
        ],
        formattedOutput: buffer.toString().trim(),
      );
    } on TimeoutException {
      return const ToolExecutionResult(
        success: false,
        summary: 'Article extraction timed out.',
        formattedOutput: 'Timed out while extracting the article.',
      );
    } catch (error) {
      return ToolExecutionResult(
        success: false,
        summary: 'Article extraction failed.',
        formattedOutput: 'Failed to extract article: $error',
      );
    }
  }

  String _extractTitle(dom.Document document) {
    final titleElement = document.querySelector('meta[property="og:title"]') ??
        document.querySelector('meta[name="twitter:title"]') ??
        document.querySelector('title') ??
        document.querySelector('h1');
    if (titleElement == null) {
      return 'Untitled';
    }
    return titleElement.attributes['content'] ?? titleElement.text.trim();
  }

  String _extractMainContent(dom.Document document) {
    document
        .querySelectorAll('script, style, nav, header, footer, aside')
        .forEach((element) => element.remove());
    final mainContent = document.querySelector('main') ??
        document.querySelector('article') ??
        document.querySelector('[role="main"]') ??
        document.querySelector('body');
    if (mainContent == null) {
      return '';
    }
    final paragraphs = mainContent.querySelectorAll('p');
    final content = paragraphs
        .map((paragraph) => paragraph.text.trim())
        .where((text) => text.length > 40)
        .take(20)
        .join('\n\n');
    if (content.isNotEmpty) {
      return content;
    }
    final ogDescription = document
        .querySelector(
          'meta[property="og:description"], meta[name="description"]',
        )
        ?.attributes['content']
        ?.trim();
    return ogDescription?.isNotEmpty == true
        ? ogDescription!
        : mainContent.text.trim();
  }

  String _extractArticleContent(dom.Document document) {
    document
        .querySelectorAll(
          'script, style, nav, header, footer, aside, .advertisement, .ad, .social-share',
        )
        .forEach((element) => element.remove());
    final article = document.querySelector('article') ??
        document.querySelector('[itemtype*="Article"]') ??
        document.querySelector('.article-content') ??
        document.querySelector('.post-content') ??
        document.querySelector('main');
    if (article == null) {
      return _extractMainContent(document);
    }
    final content = article
        .querySelectorAll('p')
        .map((paragraph) => paragraph.text.trim())
        .where((text) => text.length > 30)
        .join('\n\n');
    if (content.isNotEmpty) {
      return content;
    }
    return _extractMainContent(document);
  }

  String? _extractAuthor(dom.Document document) {
    final authorMeta = document.querySelector('meta[name="author"]') ??
        document.querySelector('meta[property="article:author"]') ??
        document.querySelector('.author') ??
        document.querySelector('[rel="author"]');
    return authorMeta?.attributes['content'] ?? authorMeta?.text.trim();
  }

  String? _extractPublishDate(dom.Document document) {
    final dateMeta =
        document.querySelector('meta[property="article:published_time"]') ??
            document.querySelector('meta[name="publish_date"]') ??
            document.querySelector('time');
    return dateMeta?.attributes['content'] ??
        dateMeta?.attributes['datetime'] ??
        dateMeta?.text.trim();
  }

  String _generateSummary(String content) {
    if (content.isEmpty) {
      return '';
    }
    final sentences = content
        .split(RegExp(r'[.!?]'))
        .where((sentence) => sentence.trim().isNotEmpty)
        .toList();
    if (sentences.isEmpty) {
      return content.length > 300 ? '${content.substring(0, 300)}...' : content;
    }
    final summary = sentences.take(3).join('. ').trim();
    return summary.length > 400 ? '${summary.substring(0, 400)}...' : '$summary.';
  }

  String? _hostnameFromUrl(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return Uri.parse(raw).host;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, String>>> _searchDuckDuckGo(
    String query, {
    required int limit,
  }) async {
    final url = Uri.https(
      'html.duckduckgo.com',
      '/html/',
      <String, String>{'q': query},
    );
    final response = await http.get(
      url,
      headers: <String, String>{
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Cache-Control': 'no-cache',
      },
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Search failed with HTTP ${response.statusCode}');
    }

    final document = html_parser.parse(response.body);
    final results = <Map<String, String>>[];
    final resultElements = document.querySelectorAll('.result, .web-result');

    for (final element in resultElements.take(limit + 3)) {
      if (results.length >= limit) {
        break;
      }
      final titleEl = element.querySelector('.result__title, .result__a');
      final snippetEl = element.querySelector('.result__snippet');
      final urlEl = element.querySelector('.result__url');
      final link = titleEl?.querySelector('a')?.attributes['href'];
      if (titleEl != null && (snippetEl != null || urlEl != null)) {
        results.add(<String, String>{
          'title': titleEl.text.trim(),
          'snippet': snippetEl?.text.trim() ?? '',
          'url': link ?? urlEl?.text.trim() ?? '',
        });
      }
    }
    return results;
  }

  Future<dom.Document> _fetchDocument(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: <String, String>{'User-Agent': _userAgent},
    ).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return html_parser.parse(response.body);
  }

  String _simplifySearchQuery(String query) {
    return query
        .trim()
        .replaceAll(
          RegExp(
            r'\b(latest|current|today|recent|newest|updated)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
