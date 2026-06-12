import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/prompt_registry.dart';

void main() {
  test('output tools prompt is built from registry-backed capabilities', () {
    final prompt = PromptRegistry.outputToolsPrompt;

    expect(prompt, contains('generate_docx'));
    expect(prompt, contains('generate_xlsx'));
    expect(prompt, contains('generate_report_pdf'));
    expect(prompt, contains('search_web'));
    expect(prompt, contains('read_url'));
  });
}
