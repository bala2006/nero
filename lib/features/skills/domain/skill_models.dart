enum SkillRequestKind { general, research, document, comparison }

SkillRequestKind skillRequestKindFromJson(String? value) {
  return switch (value) {
    'general' => SkillRequestKind.general,
    'research' => SkillRequestKind.research,
    'document' => SkillRequestKind.document,
    'comparison' => SkillRequestKind.comparison,
    _ => SkillRequestKind.general,
  };
}

String skillRequestKindToJson(SkillRequestKind kind) {
  return switch (kind) {
    SkillRequestKind.general => 'general',
    SkillRequestKind.research => 'research',
    SkillRequestKind.document => 'document',
    SkillRequestKind.comparison => 'comparison',
  };
}

enum SkillVisibility { hidden, visible, preferred }

SkillVisibility skillVisibilityFromJson(String? value) {
  return switch (value) {
    'hidden' => SkillVisibility.hidden,
    'visible' => SkillVisibility.visible,
    'preferred' => SkillVisibility.preferred,
    _ => SkillVisibility.visible,
  };
}

String skillVisibilityToJson(SkillVisibility visibility) {
  return switch (visibility) {
    SkillVisibility.hidden => 'hidden',
    SkillVisibility.visible => 'visible',
    SkillVisibility.preferred => 'preferred',
  };
}

enum SkillSideEffectPolicy {
  none,
  readOnly,
  localArtifactWrite,
  localStateWrite,
  networkWrite,
}

SkillSideEffectPolicy skillSideEffectPolicyFromJson(String? value) {
  return switch (value) {
    'none' => SkillSideEffectPolicy.none,
    'readOnly' => SkillSideEffectPolicy.readOnly,
    'localArtifactWrite' => SkillSideEffectPolicy.localArtifactWrite,
    'localStateWrite' => SkillSideEffectPolicy.localStateWrite,
    'networkWrite' => SkillSideEffectPolicy.networkWrite,
    _ => SkillSideEffectPolicy.readOnly,
  };
}

String skillSideEffectPolicyToJson(SkillSideEffectPolicy policy) {
  return switch (policy) {
    SkillSideEffectPolicy.none => 'none',
    SkillSideEffectPolicy.readOnly => 'readOnly',
    SkillSideEffectPolicy.localArtifactWrite => 'localArtifactWrite',
    SkillSideEffectPolicy.localStateWrite => 'localStateWrite',
    SkillSideEffectPolicy.networkWrite => 'networkWrite',
  };
}

enum SkillValueKind { any, string, integer, number, boolean, object, array }

SkillValueKind skillValueKindFromJson(String? value) {
  return switch (value) {
    'any' => SkillValueKind.any,
    'string' => SkillValueKind.string,
    'integer' => SkillValueKind.integer,
    'number' => SkillValueKind.number,
    'boolean' => SkillValueKind.boolean,
    'object' => SkillValueKind.object,
    'array' => SkillValueKind.array,
    _ => SkillValueKind.any,
  };
}

String skillValueKindToJson(SkillValueKind kind) {
  return switch (kind) {
    SkillValueKind.any => 'any',
    SkillValueKind.string => 'string',
    SkillValueKind.integer => 'integer',
    SkillValueKind.number => 'number',
    SkillValueKind.boolean => 'boolean',
    SkillValueKind.object => 'object',
    SkillValueKind.array => 'array',
  };
}

enum SkillStepKind {
  classify,
  gatherEvidence,
  normalizeEvidence,
  rankEvidence,
  synthesize,
  validate,
  compare,
  format,
  renderArtifact,
  persistArtifact,
  emitResponse,
  finalize,
}

String skillStepKindToJson(SkillStepKind kind) {
  return switch (kind) {
    SkillStepKind.classify => 'classify',
    SkillStepKind.gatherEvidence => 'gatherEvidence',
    SkillStepKind.normalizeEvidence => 'normalizeEvidence',
    SkillStepKind.rankEvidence => 'rankEvidence',
    SkillStepKind.synthesize => 'synthesize',
    SkillStepKind.validate => 'validate',
    SkillStepKind.compare => 'compare',
    SkillStepKind.format => 'format',
    SkillStepKind.renderArtifact => 'renderArtifact',
    SkillStepKind.persistArtifact => 'persistArtifact',
    SkillStepKind.emitResponse => 'emitResponse',
    SkillStepKind.finalize => 'finalize',
  };
}

class SkillFieldDefinition {
  const SkillFieldDefinition({
    required this.name,
    required this.kind,
    required this.description,
    this.required = false,
    this.allowEmpty = false,
    this.examples = const <Object?>[],
    this.constraints = const <String, Object?>{},
  });

  final String name;
  final SkillValueKind kind;
  final String description;
  final bool required;
  final bool allowEmpty;
  final List<Object?> examples;
  final Map<String, Object?> constraints;

  bool validateValue(Object? value) {
    if (value == null) {
      return !required;
    }
    if (!matchesKind(value)) {
      return false;
    }
    if (allowEmpty) {
      return true;
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    if (value is List) {
      return value.isNotEmpty;
    }
    if (value is Map) {
      return value.isNotEmpty;
    }
    return true;
  }

  bool matchesKind(Object? value) {
    return switch (kind) {
      SkillValueKind.any => true,
      SkillValueKind.string => value is String,
      SkillValueKind.integer => value is int,
      SkillValueKind.number => value is num,
      SkillValueKind.boolean => value is bool,
      SkillValueKind.object => value is Map,
      SkillValueKind.array => value is List,
    };
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'name': name,
      'kind': skillValueKindToJson(kind),
      'description': description,
      'required': required,
      'allowEmpty': allowEmpty,
      'examples': List<Object?>.unmodifiable(examples),
      'constraints': constraints,
    };
  }
}

class SkillContract {
  const SkillContract({
    required this.title,
    required this.description,
    required this.fields,
    this.constraints = const <String, Object?>{},
  });

  final String title;
  final String description;
  final List<SkillFieldDefinition> fields;
  final Map<String, Object?> constraints;

  SkillFieldDefinition? fieldByName(String name) {
    for (final field in fields) {
      if (field.name == name) {
        return field;
      }
    }
    return null;
  }

  List<String> validate(Map<String, Object?> input) {
    final issues = <String>[];
    for (final field in fields) {
      final hasValue = input.containsKey(field.name);
      if (!hasValue) {
        if (field.required) {
          issues.add('Missing required field: ${field.name}');
        }
        continue;
      }

      final value = input[field.name];
      if (!field.validateValue(value)) {
        issues.add('Invalid value for field: ${field.name}');
      }
    }
    return issues;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'title': title,
      'description': description,
      'fields': fields.map((field) => field.toMap()).toList(growable: false),
      'constraints': constraints,
    };
  }
}

class SkillPolicy {
  const SkillPolicy({
    required this.sideEffectPolicy,
    this.singleUse = false,
    this.requiresVerifier = true,
    this.requiresEvidence = false,
    this.approvalRequired = false,
    this.allowParallelExecution = true,
    this.maxRetries = 1,
    this.timeoutMilliseconds = 120000,
    this.metadata = const <String, Object?>{},
  });

  final SkillSideEffectPolicy sideEffectPolicy;
  final bool singleUse;
  final bool requiresVerifier;
  final bool requiresEvidence;
  final bool approvalRequired;
  final bool allowParallelExecution;
  final int maxRetries;
  final int timeoutMilliseconds;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'sideEffectPolicy': skillSideEffectPolicyToJson(sideEffectPolicy),
      'singleUse': singleUse,
      'requiresVerifier': requiresVerifier,
      'requiresEvidence': requiresEvidence,
      'approvalRequired': approvalRequired,
      'allowParallelExecution': allowParallelExecution,
      'maxRetries': maxRetries,
      'timeoutMilliseconds': timeoutMilliseconds,
      'metadata': metadata,
    };
  }
}

class SkillQualityGate {
  const SkillQualityGate({
    required this.requiredChecks,
    this.strictOutputValidation = true,
    this.metadata = const <String, Object?>{},
  });

  final List<String> requiredChecks;
  final bool strictOutputValidation;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'requiredChecks': List<String>.unmodifiable(requiredChecks),
      'strictOutputValidation': strictOutputValidation,
      'metadata': metadata,
    };
  }
}

class SkillStepDescriptor {
  const SkillStepDescriptor({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    this.capabilityKeys = const <String>[],
    this.inputKeys = const <String>[],
    this.outputKeys = const <String>[],
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String title;
  final String description;
  final SkillStepKind kind;
  final List<String> capabilityKeys;
  final List<String> inputKeys;
  final List<String> outputKeys;
  final Map<String, Object?> metadata;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'description': description,
      'kind': skillStepKindToJson(kind),
      'capabilityKeys': List<String>.unmodifiable(capabilityKeys),
      'inputKeys': List<String>.unmodifiable(inputKeys),
      'outputKeys': List<String>.unmodifiable(outputKeys),
      'metadata': metadata,
    };
  }
}

class SkillSubgraph {
  const SkillSubgraph({
    required this.entryStepId,
    required this.terminalStepId,
    required this.steps,
    this.metadata = const <String, Object?>{},
  });

  final String entryStepId;
  final String terminalStepId;
  final List<SkillStepDescriptor> steps;
  final Map<String, Object?> metadata;

  SkillStepDescriptor? stepById(String id) {
    for (final step in steps) {
      if (step.id == id) {
        return step;
      }
    }
    return null;
  }

  List<String> get stepIds =>
      steps.map((SkillStepDescriptor step) => step.id).toList(growable: false);

  List<String> validate() {
    final issues = <String>[];
    if (steps.isEmpty) {
      issues.add('Subgraph must contain at least one step.');
      return issues;
    }
    if (stepById(entryStepId) == null) {
      issues.add('Entry step not found: $entryStepId');
    }
    if (stepById(terminalStepId) == null) {
      issues.add('Terminal step not found: $terminalStepId');
    }

    final seenIds = <String>{};
    for (final step in steps) {
      if (!seenIds.add(step.id)) {
        issues.add('Duplicate step id: ${step.id}');
      }
    }

    if (steps.first.id != entryStepId) {
      issues.add('Entry step must be first: $entryStepId');
    }
    if (steps.last.id != terminalStepId) {
      issues.add('Terminal step must be last: $terminalStepId');
    }
    return issues;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'entryStepId': entryStepId,
      'terminalStepId': terminalStepId,
      'steps': steps.map((step) => step.toMap()).toList(growable: false),
      'metadata': metadata,
    };
  }
}

class SkillContext {
  const SkillContext({
    this.runId,
    this.conversationId,
    this.taskId,
    this.requestKind = SkillRequestKind.general,
    this.allowSideEffects = true,
    this.consumedSkillIds = const <String>{},
    this.allowedCapabilityKeys = const <String>{},
    this.metadata = const <String, Object?>{},
  });

  final String? runId;
  final String? conversationId;
  final String? taskId;
  final SkillRequestKind requestKind;
  final bool allowSideEffects;
  final Set<String> consumedSkillIds;
  final Set<String> allowedCapabilityKeys;
  final Map<String, Object?> metadata;

  bool get hasCapabilityConstraints => allowedCapabilityKeys.isNotEmpty;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'runId': runId,
      'conversationId': conversationId,
      'taskId': taskId,
      'requestKind': skillRequestKindToJson(requestKind),
      'allowSideEffects': allowSideEffects,
      'consumedSkillIds': _sortedStrings(consumedSkillIds),
      'allowedCapabilityKeys': _sortedStrings(allowedCapabilityKeys),
      'metadata': metadata,
    };
  }
}

class SkillDescriptor {
  const SkillDescriptor({
    required this.skillId,
    required this.version,
    required this.displayName,
    required this.purpose,
    required this.visibility,
    required this.requestKinds,
    required this.inputContract,
    required this.outputContract,
    required this.policy,
    required this.qualityGate,
    required this.subgraph,
    this.requiredCapabilityKeys = const <String>[],
    this.tags = const <String>[],
    this.enabled = true,
    this.metadata = const <String, Object?>{},
  });

  final String skillId;
  final int version;
  final String displayName;
  final String purpose;
  final SkillVisibility visibility;
  final Set<SkillRequestKind> requestKinds;
  final SkillContract inputContract;
  final SkillContract outputContract;
  final SkillPolicy policy;
  final SkillQualityGate qualityGate;
  final SkillSubgraph subgraph;
  final List<String> requiredCapabilityKeys;
  final List<String> tags;
  final bool enabled;
  final Map<String, Object?> metadata;

  bool get exposedToModel => visibility != SkillVisibility.hidden;

  bool isAvailableFor(SkillContext context) {
    if (!enabled) {
      return false;
    }
    final requestKindMatches =
        context.requestKind == SkillRequestKind.general ||
        requestKinds.contains(SkillRequestKind.general) ||
        requestKinds.contains(context.requestKind);
    if (!requestKindMatches) {
      return false;
    }
    if (policy.singleUse && context.consumedSkillIds.contains(skillId)) {
      return false;
    }
    final isSideEffecting =
        policy.sideEffectPolicy != SkillSideEffectPolicy.none &&
        policy.sideEffectPolicy != SkillSideEffectPolicy.readOnly;
    if (!context.allowSideEffects && isSideEffecting) {
      return false;
    }
    if (context.hasCapabilityConstraints && requiredCapabilityKeys.isNotEmpty) {
      for (final capabilityKey in requiredCapabilityKeys) {
        if (!context.allowedCapabilityKeys.contains(capabilityKey)) {
          return false;
        }
      }
    }
    return true;
  }

  List<String> validateStructure() {
    final issues = <String>[];
    if (inputContract.fields.isEmpty) {
      issues.add('Skill input contract must declare at least one field.');
    }
    if (outputContract.fields.isEmpty) {
      issues.add('Skill output contract must declare at least one field.');
    }
    issues.addAll(subgraph.validate());
    return issues;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'skillId': skillId,
      'version': version,
      'displayName': displayName,
      'purpose': purpose,
      'visibility': skillVisibilityToJson(visibility),
      'requestKinds': requestKinds
          .map(skillRequestKindToJson)
          .toList(growable: false),
      'inputContract': inputContract.toMap(),
      'outputContract': outputContract.toMap(),
      'policy': policy.toMap(),
      'qualityGate': qualityGate.toMap(),
      'subgraph': subgraph.toMap(),
      'requiredCapabilityKeys': List<String>.unmodifiable(requiredCapabilityKeys),
      'tags': List<String>.unmodifiable(tags),
      'enabled': enabled,
      'metadata': metadata,
    };
  }
}

List<String> _sortedStrings(Iterable<String> values) {
  final sorted = values.toList(growable: false)..sort();
  return List<String>.unmodifiable(sorted);
}
