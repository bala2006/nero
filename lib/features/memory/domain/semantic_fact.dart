class SemanticFact {
  const SemanticFact({
    required this.id,
    required this.scope,
    required this.key,
    required this.value,
    required this.confidence,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
    this.scopeId,
  });

  final String id;
  final String scope;
  final String? scopeId;
  final String key;
  final Map<String, Object?> value;
  final double confidence;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;

  SemanticFact copyWith({
    String? id,
    String? scope,
    String? scopeId,
    bool clearScopeId = false,
    String? key,
    Map<String, Object?>? value,
    double? confidence,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) {
    return SemanticFact(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      scopeId: clearScopeId ? null : scopeId ?? this.scopeId,
      key: key ?? this.key,
      value: value ?? this.value,
      confidence: confidence ?? this.confidence,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
    );
  }
}
