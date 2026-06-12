import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/diagram_render_result_handler.dart';

void main() {
  const handler = DiagramRenderResultHandler();

  test('buildAction returns null when render state is not applicable', () {
    expect(
      handler.buildAction(
        hasTask: false,
        hasRenderStep: true,
        matchesActiveAssistant: true,
        success: true,
      ),
      isNull,
    );
  });

  test('buildAction returns completed action for successful render', () {
    final action = handler.buildAction(
      hasTask: true,
      hasRenderStep: true,
      matchesActiveAssistant: true,
      success: true,
    );

    expect(action, isNotNull);
    expect(action!.status, DiagramRenderOutcomeStatus.completed);
    expect(action.detail, 'Diagram rendered successfully.');
  });

  test('buildAction returns failed action with explicit error', () {
    final action = handler.buildAction(
      hasTask: true,
      hasRenderStep: true,
      matchesActiveAssistant: true,
      success: false,
      error: 'Renderer crashed.',
    );

    expect(action, isNotNull);
    expect(action!.status, DiagramRenderOutcomeStatus.failed);
    expect(action.detail, 'Renderer crashed.');
  });
}
