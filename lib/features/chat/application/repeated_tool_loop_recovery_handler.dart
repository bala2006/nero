class RepeatedToolLoopRecoveryPlan {
  const RepeatedToolLoopRecoveryPlan({
    required this.recoveryMessage,
    required this.primaryDraftingDetail,
    required this.streamResponseDetail,
    required this.finalStatus,
  });

  final String recoveryMessage;
  final String primaryDraftingDetail;
  final String streamResponseDetail;
  final String finalStatus;
}

class RepeatedToolLoopRecoveryHandler {
  const RepeatedToolLoopRecoveryHandler();

  RepeatedToolLoopRecoveryPlan createPlan({
    required String recoveryMessage,
  }) {
    return RepeatedToolLoopRecoveryPlan(
      recoveryMessage: recoveryMessage,
      primaryDraftingDetail: 'Recovered locally after a repeated tool-call loop.',
      streamResponseDetail:
          'Recovered from a repeated tool-call loop and finalized locally.',
      finalStatus: 'Done',
    );
  }
}
