import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/active_request_session.dart';
import 'package:nero/features/settings/app_settings.dart';

void main() {
  test('begin stores prompt, api key, settings, and resets selected tools', () {
    final session = ActiveRequestSession();
    const settings = NeroSettings(
      azureApiKey: 'sk_test',
      selectedModelId: 'sarvam-105b',
    );

    session.setSelectedTools(const <String>['search_web']);
    session.begin(
      apiKey: 'sk_test',
      settings: settings,
      prompt: 'research this',
    );

    expect(session.apiKey, 'sk_test');
    expect(session.settings, settings);
    expect(session.prompt, 'research this');
    expect(session.selectedTools, isEmpty);
  });

  test('setSelectedTools and clearSelectedTools manage immutable selection state', () {
    final session = ActiveRequestSession();

    session.setSelectedTools(const <String>['search_web', 'read_url']);
    expect(session.selectedTools, ['search_web', 'read_url']);

    session.clearSelectedTools();
    expect(session.selectedTools, isEmpty);
  });

  test('clear resets all request session state', () {
    final session = ActiveRequestSession();
    const settings = NeroSettings(
      azureApiKey: 'sk_test',
      selectedModelId: 'sarvam-105b',
    );

    session.begin(
      apiKey: 'sk_test',
      settings: settings,
      prompt: 'build a doc',
    );
    session.setSelectedTools(const <String>['generate_docx']);

    session.clear();

    expect(session.apiKey, isNull);
    expect(session.settings, isNull);
    expect(session.prompt, isNull);
    expect(session.selectedTools, isEmpty);
  });
}
