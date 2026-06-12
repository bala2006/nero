import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';

class WebViewMermaid extends StatefulWidget {
  const WebViewMermaid({
    super.key,
    required this.code,
    this.height,
    this.onRenderResult,
    this.onPngReady,
  });

  final String code;
  final double? height;
  final void Function(bool success, String? error)? onRenderResult;
  final void Function(String pngDataUrl)? onPngReady;

  @override
  State<WebViewMermaid> createState() => _WebViewMermaidState();
}

class _WebViewMermaidState extends State<WebViewMermaid> {
  static const int _htmlCacheLimit = 8;
  static final LinkedHashMap<String, String> _htmlCache =
      LinkedHashMap<String, String>();

  // Pre-compiled regex patterns for _normalizeMermaidCode
  static final _ellipsisRegex = RegExp(r'^\s*\.\.\.\s*');

  // Pre-compiled regex patterns for _repairMermaidLine
  static final _arrowDashRegex = RegExp(r'\s*--\s*>');
  static final _arrowMinusRegex = RegExp(r'\s*-\s*>');
  static final _arrowEqRegex = RegExp(r'\s*==>\s*');
  static final _whitespaceRegex = RegExp(r'\s+');

  // Pre-compiled regex patterns for node token repair
  static final _nodeIdSquarePattern = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\[(.*)\]$');
  static final _nodeIdParenPattern = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\((.*)\)$');
  static final _nodeIdCurlyPattern = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\{(.*)\}$');
  static final _simpleNodeIdPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

  // Pre-compiled regex patterns for _looksLikeMermaidContentLine
  static final _contentLinePattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]*[\[\(\{]');

  // Pre-compiled regex patterns for _looksLikeTrailingNonMermaidSection
  static final _proseSectionPattern = RegExp(
    r'^(#{1,6}\s|[-*]\s|\d+\.\s|Problem statement|Approach|Explanation|Visual diagram|Diagram|Code solution|Code|Summary|Conclusion)\b',
    caseSensitive: false,
  );

  // Pre-compiled regex patterns for _repairFlowLine
  static final _flowArrowSplitRegex = RegExp(r'\s+-->\s+');

  // Pre-compiled regex patterns for _sanitizeMermaidLabel
  static final _bracketRegex = RegExp(r'[\[\]\{\}]');

  // Pre-compiled regex patterns for _looksLikeDiagramStart
  static final _diagramStartPattern = RegExp(
    r'^(graph|flowchart|sequenceDiagram|classDiagram|stateDiagram(?:-v2)?|erDiagram|journey|gantt|pie|gitGraph|mindmap|timeline|zenuml|quadrantChart|requirementDiagram|C4Context|C4Container|C4Component|C4Dynamic|C4Deployment)\b',
    caseSensitive: false,
  );

  late final WebViewController _controller;
  late final PlatformWebViewWidgetCreationParams _widgetParams;
  String _lastNormalizedCode = '';
  String _html = '';
  bool _isLoading = true;
  String? _error;
  double _contentHeight = 400;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  PlatformWebViewWidgetCreationParams _createWidgetParams() {
    final baseParams = PlatformWebViewWidgetCreationParams(
      controller: _controller.platform,
      layoutDirection: TextDirection.ltr,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<EagerGestureRecognizer>(
          () => EagerGestureRecognizer(),
        ),
      },
    );
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      return AndroidWebViewWidgetCreationParams
          .fromPlatformWebViewWidgetCreationParams(
        baseParams,
        displayWithHybridComposition: true,
      );
    }
    return baseParams;
  }

  void _initializeWebView() {
    _lastNormalizedCode = _normalizeMermaidCode(widget.code);
    _html = _buildHtml(_lastNormalizedCode);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1E1E1E))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.prevent;
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          final data = jsonDecode(message.message);
          if (data is! Map<String, dynamic>) {
            return;
          }
          if (data['type'] == 'height') {
            setState(() {
              _contentHeight = (data['value'] as num).toDouble();
              _isLoading = false;
            });
            widget.onRenderResult?.call(true, null);
          } else if (data['type'] == 'png') {
            final pngData = data['value']?.toString();
            if (pngData != null && pngData.trim().isNotEmpty) {
              widget.onPngReady?.call(pngData);
            }
          } else if (data['type'] == 'error') {
            setState(() {
              _error = data['message']?.toString() ?? 'Unknown Mermaid error';
              _isLoading = false;
            });
            widget.onRenderResult?.call(false, _error);
          } else if (data['type'] == 'ready') {
            setState(() {
              _isLoading = false;
            });
          }
        },
      )
      ..loadHtmlString(_html);
    _widgetParams = _createWidgetParams();
  }

  String _buildHtml(String normalizedCode) {
    final cached = _htmlCache[normalizedCode];
    if (cached != null) {
      return cached;
    }
    final escapedCode = jsonEncode(normalizedCode);

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=0.5, maximum-scale=3.0, user-scalable=yes">
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      background: #1E1E1E;
      overflow: auto;
      padding: 16px;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      min-width: 100vw;
      min-height: 100vh;
    }
    #diagram {
      display: inline-block;
      min-width: max-content;
      text-align: center;
      min-height: 100px;
    }
    #diagram svg {
      max-width: 100%;
      height: auto;
    }
    #diagram .nodeLabel,
    #diagram .edgeLabel,
    #diagram .label {
      white-space: normal !important;
      word-wrap: break-word !important;
      overflow-wrap: break-word !important;
      max-width: 220px;
      line-height: 1.4;
    }
    .error {
      color: #FCA5A5;
      padding: 12px;
      background: rgba(220, 38, 38, 0.1);
      border-radius: 8px;
      font-size: 12px;
      text-align: left;
    }
  </style>
</head>
<body>
  <div id="diagram"></div>
  <script>
    mermaid.initialize({
      startOnLoad: false,
      theme: 'dark',
      themeVariables: {
        darkMode: true,
        primaryColor: '#E07B52',
        primaryTextColor: '#FFFFFF',
        primaryBorderColor: '#E07B52',
        lineColor: '#D6D0C8',
        secondaryColor: '#B89B72',
        tertiaryColor: '#716B64',
        background: '#1E1E1E',
        mainBkg: '#1E1E1E',
        secondBkg: '#2D2D2D',
        tertiaryBkg: '#3D3D3D',
        fontSize: '16px',
        fontFamily: 'Inter, sans-serif'
      },
      flowchart: {
        curve: 'basis',
        padding: 30,
        nodeSpacing: 80,
        rankSpacing: 80,
        diagramPadding: 20,
        htmlLabels: true,
        useMaxWidth: false,
        maxTextSize: 90000,
        wrap: true
      },
      sequence: {
        actorMargin: 80,
        boxMargin: 20,
        messageMargin: 50,
        diagramMarginX: 20,
        diagramMarginY: 20
      }
    });

    function sendToFlutter(type, data) {
      FlutterBridge.postMessage(JSON.stringify({
        type: type,
        ...data
      }));
    }

    async function renderDiagram() {
      try {
        const code = $escapedCode;
        const { svg } = await mermaid.render('mermaid-svg', code);
        document.getElementById('diagram').innerHTML = svg;
        const svgBlob = new Blob([svg], { type: 'image/svg+xml;charset=utf-8' });
        const svgUrl = URL.createObjectURL(svgBlob);
        const image = new Image();
        image.onload = function() {
          const width = Math.max(1, Math.ceil(image.naturalWidth || image.width || 1));
          const height = Math.max(1, Math.ceil(image.naturalHeight || image.height || 1));
          const canvas = document.createElement('canvas');
          canvas.width = width;
          canvas.height = height;
          const context = canvas.getContext('2d');
          if (context) {
            context.drawImage(image, 0, 0, width, height);
            sendToFlutter('png', { value: canvas.toDataURL('image/png') });
          }
          URL.revokeObjectURL(svgUrl);
        };
        image.onerror = function() {
          URL.revokeObjectURL(svgUrl);
        };
        image.src = svgUrl;
        setTimeout(() => {
          const height = document.body.scrollHeight;
          sendToFlutter('height', { value: height });
        }, 100);
      } catch (error) {
        document.getElementById('diagram').innerHTML =
          '<div class="error">Failed to render diagram: ' + error.message + '</div>';
        sendToFlutter('error', { message: error.message });
      }
    }

    document.addEventListener('DOMContentLoaded', () => {
      renderDiagram();
    });

    if (document.readyState === 'complete' || document.readyState === 'interactive') {
      setTimeout(renderDiagram, 1);
    }
  </script>
</body>
</html>
''';
    if (_htmlCache.length >= _htmlCacheLimit) {
      _htmlCache.remove(_htmlCache.keys.first);
    }
    _htmlCache[normalizedCode] = html;
    return html;
  }

  String _normalizeMermaidCode(String raw) {
    final normalizedNewlines = raw.replaceAll('\r\n', '\n').trim();
    if (normalizedNewlines.isEmpty) {
      return raw;
    }

    final lines = normalizedNewlines
        .split('\n')
        .map(
          (line) => line
              .replaceFirst(_ellipsisRegex, '')
              .replaceAll('```mermaid', '')
              .replaceAll('```', ''),
        )
        .toList(growable: false);

    final firstDiagramIndex = lines.indexWhere(_looksLikeDiagramStart);
    final relevantLines = firstDiagramIndex >= 0
        ? lines.sublist(firstDiagramIndex)
        : lines;

    final cleaned = <String>[];
    var started = false;
    for (final line in relevantLines) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        if (started) {
          cleaned.add('');
        }
        continue;
      }
      if (_looksLikeProseNoise(trimmed)) {
        continue;
      }
      if (!started && !_looksLikeMermaidContentLine(trimmed)) {
        continue;
      }
      if (started && _looksLikeTrailingNonMermaidSection(trimmed)) {
        break;
      }
      started = true;
      cleaned.add(trimmed);
    }

    return _repairMermaidCode(cleaned.join('\n').trim());
  }

  String _repairMermaidCode(String raw) {
    if (raw.isEmpty) {
      return raw;
    }

    final repairedLines = raw
        .split('\n')
        .map(_repairMermaidLine)
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    return repairedLines.join('\n').trim();
  }

  String _repairMermaidLine(String line) {
    var value = line.trimRight();
    if (value.isEmpty) {
      return value;
    }

    value = value
        .replaceAll('→', '-->')
        .replaceAll('⟶', '-->')
        .replaceAll('⇒', '-->')
        .replaceAll(_arrowDashRegex, ' --> ')
        .replaceAll(_arrowMinusRegex, ' --> ')
        .replaceAll(_arrowEqRegex, ' --> ')
        .replaceAll(_whitespaceRegex, ' ');

    if (value.startsWith('graph ') || value.startsWith('flowchart ')) {
      return value;
    }
    if (value == 'end') {
      return value;
    }
    if (value.startsWith('subgraph ')) {
      return _repairSubgraphLine(value);
    }
    if (_looksLikeFlowLine(value)) {
      return _repairFlowLine(value);
    }

    value = value.replaceAllMapped(
      RegExp(r'([A-Za-z][A-Za-z0-9_]*)\[(.+?)\]'),
      (match) {
        final nodeId = match.group(1)!;
        final label = _sanitizeMermaidLabel(match.group(2)!);
        return '$nodeId["$label"]';
      },
    );

    value = value.replaceAllMapped(
      RegExp(r'([A-Za-z][A-Za-z0-9_]*)\((.+?)\)'),
      (match) {
        final nodeId = match.group(1)!;
        final label = _sanitizeMermaidLabel(match.group(2)!);
        return '$nodeId("$label")';
      },
    );

    return value;
  }

  String _repairSubgraphLine(String value) {
    final rest = value.substring('subgraph '.length).trim();
    if (rest.isEmpty) {
      return 'subgraph Group';
    }
    final safe = _sanitizeMermaidLabel(rest);
    return 'subgraph "$safe"';
  }

  bool _looksLikeFlowLine(String value) {
    return value.contains('-->') ||
        value.contains('---') ||
        value.contains('-.->') ||
        value.contains('==>');
  }

  bool _looksLikeMermaidContentLine(String value) {
    final trimmed = value.trimLeft();
    if (_looksLikeDiagramStart(trimmed)) {
      return true;
    }
    return trimmed == 'end' ||
        trimmed.startsWith('subgraph ') ||
        trimmed.startsWith('style ') ||
        trimmed.startsWith('classDef ') ||
        trimmed.startsWith('class ') ||
        trimmed.startsWith('linkStyle ') ||
        trimmed.startsWith('click ') ||
        trimmed.startsWith('section ') ||
        trimmed.startsWith('title ') ||
        trimmed.startsWith('accTitle:') ||
        trimmed.startsWith('accDescr:') ||
        _looksLikeFlowLine(trimmed) ||
        _contentLinePattern.hasMatch(trimmed);
  }

  bool _looksLikeTrailingNonMermaidSection(String value) {
    final trimmed = value.trimLeft();
    return _proseSectionPattern.hasMatch(trimmed);
  }

  String _repairFlowLine(String value) {
    final normalized = value
        .replaceAll('-.->', '-->')
        .replaceAll('---', '-->')
        .replaceAll('==>', '-->');
    final parts = normalized.split(_flowArrowSplitRegex);
    if (parts.length <= 1) {
      return value;
    }
    final repaired = <String>[];
    for (var i = 0; i < parts.length; i++) {
      repaired.add(_repairNodeToken(parts[i], i));
    }
    return repaired.join(' --> ');
  }

  String _repairNodeToken(String token, int index) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return 'N$index["Node ${index + 1}"]';
    }
    if (trimmed == 'end' || trimmed.startsWith('subgraph ')) {
      return trimmed;
    }

    final squareMatch = _nodeIdSquarePattern.firstMatch(trimmed);
    if (squareMatch != null) {
      final nodeId = squareMatch.group(1)!;
      final label = _sanitizeMermaidLabel(squareMatch.group(2)!);
      return '$nodeId["$label"]';
    }

    final roundMatch = _nodeIdParenPattern.firstMatch(trimmed);
    if (roundMatch != null) {
      final nodeId = roundMatch.group(1)!;
      final label = _sanitizeMermaidLabel(roundMatch.group(2)!);
      return '$nodeId("$label")';
    }

    final curlyMatch = _nodeIdCurlyPattern.firstMatch(trimmed);
    if (curlyMatch != null) {
      final nodeId = curlyMatch.group(1)!;
      final label = _sanitizeMermaidLabel(curlyMatch.group(2)!);
      return '$nodeId{"$label"}';
    }

    if (_simpleNodeIdPattern.hasMatch(trimmed)) {
      return trimmed;
    }

    final generatedId = 'N$index';
    final label = _sanitizeMermaidLabel(trimmed);
    return '$generatedId["$label"]';
  }

  String _sanitizeMermaidLabel(String raw) {
    return raw
        .replaceAll(_bracketRegex, '')
        .replaceAll('"', "'")
        .replaceAll('`', '')
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('|', '/')
        .replaceAll(_whitespaceRegex, ' ')
        .trim();
  }

  bool _looksLikeDiagramStart(String line) {
    final trimmed = line.trimLeft();
    return _diagramStartPattern.hasMatch(trimmed);
  }

  bool _looksLikeProseNoise(String line) {
    final trimmed = line.trimLeft();
    if (trimmed == '...' || trimmed == '```') {
      return true;
    }
    if (trimmed.startsWith('Here is') ||
        trimmed.startsWith('This diagram') ||
        trimmed.startsWith('Below is')) {
      return true;
    }
    return false;
  }

  @override
  void didUpdateWidget(WebViewMermaid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextNormalizedCode = _normalizeMermaidCode(widget.code);
    if (nextNormalizedCode == _lastNormalizedCode) {
      return;
    }
    _lastNormalizedCode = nextNormalizedCode;
    if (oldWidget.code != widget.code) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      _html = _buildHtml(nextNormalizedCode);
      _controller.loadHtmlString(_html);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'Could not render diagram',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: widget.height ?? _contentHeight,
      child: Stack(
        children: [
          WebViewWidget.fromPlatformCreationParams(
            params: _widgetParams,
          ),
          if (_isLoading)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.tealBright,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
