enum AuditLogStatus {
  started,
  success,
  failed,
}

AuditLogStatus auditLogStatusFromJson(String? value) {
  return switch (value) {
    'started' => AuditLogStatus.started,
    'success' => AuditLogStatus.success,
    'failed' => AuditLogStatus.failed,
    _ => AuditLogStatus.started,
  };
}

String auditLogStatusToJson(AuditLogStatus status) {
  return switch (status) {
    AuditLogStatus.started => 'started',
    AuditLogStatus.success => 'success',
    AuditLogStatus.failed => 'failed',
  };
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.createdAtEpochMs,
    required this.capabilityKey,
    required this.title,
    required this.status,
    this.detail,
    this.conversationId,
  });

  final String id;
  final int createdAtEpochMs;
  final String capabilityKey;
  final String title;
  final AuditLogStatus status;
  final String? detail;
  final String? conversationId;
}
