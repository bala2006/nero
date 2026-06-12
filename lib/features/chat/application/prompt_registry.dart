import '../../capabilities/domain/capability_registry.dart';

class PromptRegistry {
  PromptRegistry._();

  static final String outputToolsPrompt = buildOutputToolsPrompt();

  static String buildOutputToolsPrompt({
    Iterable<CapabilityDefinition>? capabilities,
  }) {
    final resolvedCapabilities =
        capabilities ?? CapabilityRegistry.visibleToModel();
    final webTools = resolvedCapabilities
        .where(
          (capability) =>
              capability.category == CapabilityCategory.read &&
              capability.toolDescriptor != null,
        )
        .map((capability) => capability.toolDescriptor!)
        .toList(growable: false);
    final outputTools = resolvedCapabilities
        .where(
          (capability) =>
              capability.category == CapabilityCategory.build &&
              capability.toolDescriptor != null,
        )
        .map((capability) => capability.toolDescriptor!)
        .toList(growable: false);

    final buffer = StringBuffer()
      ..writeln('Available output tools in this chat UI:')
      ..writeln(
        '- Code container: use fenced code blocks with a precise language tag, for example ```dart or ```python.',
      )
      ..writeln(
        '- Diagram container: use fenced Mermaid blocks, for example ```mermaid.',
      )
      ..writeln(
        '- Table container: use valid Markdown tables with a header row and divider row.',
      )
      ..writeln(
        '- Preferred structured block contract: When returning a code block, diagram, or table, prefer Nero block markers exactly in this form:',
      )
      ..writeln('  [[NERO_BLOCK:CODE lang=python]]')
      ..writeln('  ...content...')
      ..writeln('  [[/NERO_BLOCK]]')
      ..writeln('  [[NERO_BLOCK:DIAGRAM lang=mermaid]]')
      ..writeln('  ...content...')
      ..writeln('  [[/NERO_BLOCK]]')
      ..writeln('  [[NERO_BLOCK:TABLE]]')
      ..writeln('  | ... |')
      ..writeln('  [[/NERO_BLOCK]]')
      ..writeln(
        '- Formatting tools: use short headings, bullets, numbered lists, blockquotes, and bold text when they improve readability.',
      );

    if (webTools.isNotEmpty) {
      buffer.writeln(
        '- Web tools: ${webTools.map((tool) => tool.name).join(', ')} when current or external information is needed.',
      );
    }
    if (outputTools.isNotEmpty) {
      buffer.writeln(
        '- Output tools: ${outputTools.map((tool) => tool.name).join(', ')} when the user asks for a downloadable artifact instead of a faux file in chat.',
      );
    }

    buffer
      ..writeln(
        'Do not describe a table, code block, or diagram when the user asked for one; emit the formatted artifact directly.',
      )
      ..writeln(
        'For code tasks, prefer code first and concise explanation second.',
      )
      ..writeln(
        'For diagrams, output only one valid Mermaid block unless the user asks for multiple.',
      )
      ..writeln(
        'For long answers with multiple examples, include at most one simple Mermaid diagram for the overall concept unless the user explicitly asks for a diagram per item.',
      )
      ..writeln(
        'Keep Mermaid syntax minimal and valid: one statement per line, short node labels, and no prose outside the fenced Mermaid block.',
      )
      ..writeln(
        'For tables, keep the table structurally valid and aligned to the user request.',
      )
      ..writeln(
        'Do not wrap [[NERO_BLOCK:...]] markers inside markdown code fences.',
      )
      ..writeln(
        'Do not emit standalone labels like "**Code**", "**Diagram**", "Code Solution:", or "Visual Diagram:" before an artifact block.',
      )
      ..writeln(
        'If you begin a [[NERO_BLOCK:...]] section, finish it with [[/NERO_BLOCK]] before moving to normal prose.',
      )
      ..writeln(
        'If you use web tools, synthesize the results into a direct final answer after the tool results are available.',
      )
      ..writeln(
        'If you use an output file tool, keep the final chat answer brief and tell the user the generated artifact is attached.',
      )
      ..write(
        'Never expose internal tool execution markers, placeholders, or meta messages to the user.',
      );

    return buffer.toString();
  }
}
