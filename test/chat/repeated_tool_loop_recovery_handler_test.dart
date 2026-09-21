import 'package:flutter_test/flutter_test.dart';
import 'package:nero/features/chat/application/repeated_tool_loop_recovery_handler.dart';

void main() {
  const handler = RepeatedToolLoopRecoveryHandler();

  test('createPlan returns stable recovery messaging', () {
    final plan = handler.createPlan(
      recoveryMessage: 'I created the document and attached it above.',
    );

    expect(
      plan.primaryDraftingDetail,
      'Recovered locally after a repeated tool-call loop.',
    );
    expect(
      plan.streamResponseDetail,
      'Recovered from a repeated tool-call loop and finalized locally.',
    );
    expect(plan.finalStatus, 'Done');
    expect(plan.recoveryMessage, 'I created the document and attached it above.');
  });
}
