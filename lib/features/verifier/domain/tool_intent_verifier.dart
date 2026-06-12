import '../../capabilities/capabilities.dart';
import 'verification_models.dart';

class ToolIntentVerificationRequest {
  const ToolIntentVerificationRequest({
    required this.toolIntents,
    this.allowedToolNames = const <String>[],
    this.consumedSingleUseToolNames = const <String>[],
  });

  final List<ToolIntent> toolIntents;
  final List<String> allowedToolNames;
  final List<String> consumedSingleUseToolNames;
}

class ToolIntentVerifier {
  const ToolIntentVerifier();

  ToolIntentVerificationResult verify(ToolIntentVerificationRequest request) {
    final allowedToolNames = request.allowedToolNames.isEmpty
        ? CapabilityRegistry.modelToolNames().toSet()
        : request.allowedToolNames.toSet();
    final consumedSingleUseToolNames = request.consumedSingleUseToolNames
        .toSet();

    final accepted = <VerifiedToolIntent>[];
    final rejected = <RejectedToolIntent>[];
    final issues = <VerificationIssue>[];
    final seenSingleUseToolNames = <String>{};

    for (final intent in request.toolIntents) {
      final callIssues = <VerificationIssue>[];
      final capability = CapabilityRegistry.byToolName(intent.name);

      if (capability == null) {
        callIssues.add(
          VerificationIssue(
            code: 'tool.intent.unknown_tool',
            message: 'Unknown tool intent "${intent.name}".',
            severity: VerificationSeverity.blocking,
            fieldPath: 'toolIntents.${intent.id}.name',
            subject: intent.name,
          ),
        );
      } else {
        if (!allowedToolNames.contains(intent.name)) {
          callIssues.add(
            VerificationIssue(
              code: 'tool.intent.disallowed_tool',
              message:
                  'Tool "${intent.name}" is not allowed in the current run.',
              severity: VerificationSeverity.blocking,
              fieldPath: 'toolIntents.${intent.id}.name',
              subject: intent.name,
            ),
          );
        }

        if (capability.singleUse) {
          if (consumedSingleUseToolNames.contains(intent.name) ||
              !seenSingleUseToolNames.add(intent.name)) {
            callIssues.add(
              VerificationIssue(
                code: 'tool.intent.single_use_reuse',
                message:
                    'Single-use tool "${intent.name}" was already consumed earlier in this run.',
                severity: VerificationSeverity.blocking,
                fieldPath: 'toolIntents.${intent.id}.name',
                subject: intent.name,
              ),
            );
          }
        }

        callIssues.addAll(
          _validateArguments(
            capability: capability,
            arguments: intent.arguments,
            intentId: intent.id,
          ),
        );
        if (capability.toolName == 'generate_xlsx') {
          callIssues.addAll(
            _validateSpreadsheetArguments(
              arguments: intent.arguments,
              intentId: intent.id,
            ),
          );
        }
        if (capability.toolName == 'generate_report_pdf') {
          callIssues.addAll(
            _validatePdfArguments(
              arguments: intent.arguments,
              intentId: intent.id,
            ),
          );
        }
      }

      if (callIssues.isEmpty) {
        accepted.add(
          VerifiedToolIntent(intent: intent, capabilityKey: capability!.key),
        );
      } else {
        rejected.add(RejectedToolIntent(intent: intent, issues: callIssues));
        issues.addAll(callIssues);
      }
    }

    return ToolIntentVerificationResult(
      report: VerificationReport(
        target: VerificationTarget.toolIntent,
        subject: request.toolIntents.isEmpty
            ? null
            : request.toolIntents.map((intent) => intent.name).join(', '),
        issues: List<VerificationIssue>.unmodifiable(issues),
      ),
      acceptedIntents: List<VerifiedToolIntent>.unmodifiable(accepted),
      rejectedIntents: List<RejectedToolIntent>.unmodifiable(rejected),
    );
  }

  List<VerificationIssue> _validateArguments({
    required CapabilityDefinition capability,
    required Map<String, Object?> arguments,
    required String intentId,
  }) {
    final schema = capability.toolDescriptor?.parameters;
    if (schema == null || schema.isEmpty) {
      return const <VerificationIssue>[];
    }

    return _validateSchemaNode(
      schema: schema,
      value: arguments,
      path: 'toolIntents.$intentId.arguments',
      subject: capability.toolName,
    );
  }

  List<VerificationIssue> _validateSchemaNode({
    required Map<String, Object?> schema,
    required Object? value,
    required String path,
    required String? subject,
  }) {
    final issues = <VerificationIssue>[];
    final type = schema['type']?.toString();

    switch (type) {
      case 'object':
        if (value is! Map) {
          issues.add(
            VerificationIssue(
              code: 'tool.intent.invalid_type',
              message: 'Expected an object at $path.',
              severity: VerificationSeverity.blocking,
              fieldPath: path,
              subject: subject,
              details: <String, Object?>{'expected': 'object'},
            ),
          );
          return issues;
        }

        final objectValue = Map<String, Object?>.from(value);
        final properties = _readObjectMap(schema['properties']);
        final requiredKeys = _readStringList(schema['required']);
        final additionalProperties =
            schema['additionalProperties'] as bool? ?? true;

        for (final requiredKey in requiredKeys) {
          if (!objectValue.containsKey(requiredKey)) {
            issues.add(
              VerificationIssue(
                code: 'tool.intent.missing_required',
                message: 'Missing required field "$requiredKey" at $path.',
                severity: VerificationSeverity.blocking,
                fieldPath: '$path.$requiredKey',
                subject: subject,
              ),
            );
            continue;
          }

          final childValue = objectValue[requiredKey];
          final childSchema = properties[requiredKey];
          if (childSchema != null) {
            issues.addAll(
              _validateSchemaNode(
                schema: childSchema,
                value: childValue,
                path: '$path.$requiredKey',
                subject: subject,
              ),
            );
          } else if (_isBlankValue(childValue)) {
            issues.add(
              VerificationIssue(
                code: 'tool.intent.invalid_value',
                message: 'Field "$requiredKey" at $path cannot be empty.',
                severity: VerificationSeverity.blocking,
                fieldPath: '$path.$requiredKey',
                subject: subject,
              ),
            );
          }
        }

        if (!additionalProperties) {
          for (final key in objectValue.keys) {
            if (!properties.containsKey(key)) {
              issues.add(
                VerificationIssue(
                  code: 'tool.intent.unexpected_property',
                  message: 'Unexpected field "$key" at $path.',
                  severity: VerificationSeverity.blocking,
                  fieldPath: '$path.$key',
                  subject: subject,
                ),
              );
            }
          }
        }

        for (final entry in objectValue.entries) {
          final childSchema = properties[entry.key];
          if (childSchema == null) {
            continue;
          }
          issues.addAll(
            _validateSchemaNode(
              schema: childSchema,
              value: entry.value,
              path: '$path.${entry.key}',
              subject: subject,
            ),
          );
        }
        return issues;

      case 'array':
        if (value is! List) {
          issues.add(
            VerificationIssue(
              code: 'tool.intent.invalid_type',
              message: 'Expected a list at $path.',
              severity: VerificationSeverity.blocking,
              fieldPath: path,
              subject: subject,
              details: <String, Object?>{'expected': 'array'},
            ),
          );
          return issues;
        }

        final minItems = _readInt(schema['minItems']);
        if (minItems != null && value.length < minItems) {
          issues.add(
            VerificationIssue(
              code: 'tool.intent.invalid_value',
              message: 'Expected at least $minItems item(s) at $path.',
              severity: VerificationSeverity.blocking,
              fieldPath: path,
              subject: subject,
            ),
          );
        }

        final itemSchema = schema['items'];
        if (itemSchema is Map) {
          final itemSchemaMap = Map<String, Object?>.from(itemSchema);
          for (var index = 0; index < value.length; index++) {
            issues.addAll(
              _validateSchemaNode(
                schema: itemSchemaMap,
                value: value[index],
                path: '$path[$index]',
                subject: subject,
              ),
            );
          }
        }
        return issues;

      case 'string':
        if (value is! String) {
          issues.add(
            VerificationIssue(
              code: 'tool.intent.invalid_type',
              message: 'Expected a string at $path.',
              severity: VerificationSeverity.blocking,
              fieldPath: path,
              subject: subject,
              details: <String, Object?>{'expected': 'string'},
            ),
          );
          return issues;
        }

        final minLength = _readInt(schema['minLength']);
        if (minLength != null && value.trim().length < minLength) {
          issues.add(
            VerificationIssue(
              code: 'tool.intent.invalid_value',
              message: 'Expected at least $minLength character(s) at $path.',
              severity: VerificationSeverity.blocking,
              fieldPath: path,
              subject: subject,
            ),
          );
        }

        final allowedValues = _readStringList(schema['enum']);
        if (allowedValues.isNotEmpty && !allowedValues.contains(value)) {
          issues.add(
            VerificationIssue(
              code: 'tool.intent.invalid_value',
              message:
                  'Value "$value" at $path is not one of the allowed options.',
              severity: VerificationSeverity.blocking,
              fieldPath: path,
              subject: subject,
            ),
          );
        }
        return issues;

      case 'integer':
        if (!_isIntegerLike(value)) {
          issues.add(
            VerificationIssue(
              code: 'tool.intent.invalid_type',
              message: 'Expected an integer at $path.',
              severity: VerificationSeverity.blocking,
              fieldPath: path,
              subject: subject,
              details: <String, Object?>{'expected': 'integer'},
            ),
          );
        }
        return issues;

      case 'number':
        if (value is! num) {
          issues.add(
            VerificationIssue(
              code: 'tool.intent.invalid_type',
              message: 'Expected a number at $path.',
              severity: VerificationSeverity.blocking,
              fieldPath: path,
              subject: subject,
              details: <String, Object?>{'expected': 'number'},
            ),
          );
        }
        return issues;

      case 'boolean':
        if (value is! bool) {
          issues.add(
            VerificationIssue(
              code: 'tool.intent.invalid_type',
              message: 'Expected a boolean at $path.',
              severity: VerificationSeverity.blocking,
              fieldPath: path,
              subject: subject,
              details: <String, Object?>{'expected': 'boolean'},
            ),
          );
        }
        return issues;

      default:
        return issues;
    }
  }

  List<VerificationIssue> _validateSpreadsheetArguments({
    required Map<String, Object?> arguments,
    required String intentId,
  }) {
    final issues = <VerificationIssue>[];
    final title = arguments['title'];
    final sheets = arguments['sheets'];

    if (title is! String || title.trim().isEmpty) {
      issues.add(
        VerificationIssue(
          code: 'tool.intent.invalid_value',
          message: 'Spreadsheet title must be a non-empty string.',
          severity: VerificationSeverity.blocking,
          fieldPath: 'toolIntents.$intentId.arguments.title',
          subject: 'generate_xlsx',
        ),
      );
    }

    if (sheets is! List || sheets.isEmpty) {
      issues.add(
        VerificationIssue(
          code: 'tool.intent.invalid_value',
          message: 'Spreadsheet sheets must be a non-empty list.',
          severity: VerificationSeverity.blocking,
          fieldPath: 'toolIntents.$intentId.arguments.sheets',
          subject: 'generate_xlsx',
        ),
      );
      return issues;
    }

    for (var index = 0; index < sheets.length; index++) {
      final rawSheet = sheets[index];
      if (rawSheet is! Map) {
        issues.add(
          VerificationIssue(
            code: 'tool.intent.invalid_type',
            message: 'Each spreadsheet sheet must be an object.',
            severity: VerificationSeverity.blocking,
            fieldPath: 'toolIntents.$intentId.arguments.sheets[$index]',
            subject: 'generate_xlsx',
          ),
        );
        continue;
      }

      final sheet = Map<String, Object?>.from(rawSheet);
      final sheetName = sheet['name'];
      final rows = sheet['rows'];

      if (sheetName is! String || sheetName.trim().isEmpty) {
        issues.add(
          VerificationIssue(
            code: 'tool.intent.invalid_value',
            message: 'Each spreadsheet sheet requires a non-empty name.',
            severity: VerificationSeverity.blocking,
            fieldPath: 'toolIntents.$intentId.arguments.sheets[$index].name',
            subject: 'generate_xlsx',
          ),
        );
      }

      if (rows is! List || rows.isEmpty) {
        issues.add(
          VerificationIssue(
            code: 'tool.intent.invalid_value',
            message: 'Each spreadsheet sheet requires a non-empty rows matrix.',
            severity: VerificationSeverity.blocking,
            fieldPath: 'toolIntents.$intentId.arguments.sheets[$index].rows',
            subject: 'generate_xlsx',
          ),
        );
        continue;
      }

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        if (row is! List) {
          issues.add(
            VerificationIssue(
              code: 'tool.intent.invalid_type',
              message: 'Spreadsheet rows must be lists of cell values.',
              severity: VerificationSeverity.blocking,
              fieldPath:
                  'toolIntents.$intentId.arguments.sheets[$index].rows[$rowIndex]',
              subject: 'generate_xlsx',
            ),
          );
        }
      }
    }

    return issues;
  }

  List<VerificationIssue> _validatePdfArguments({
    required Map<String, Object?> arguments,
    required String intentId,
  }) {
    final issues = <VerificationIssue>[];
    final orientation = arguments['orientation'];
    final paperSize = arguments['paper_size'];

    if (orientation != null) {
      final normalized = orientation.toString().trim().toLowerCase();
      if (normalized.isNotEmpty &&
          normalized != 'portrait' &&
          normalized != 'landscape') {
        issues.add(
          VerificationIssue(
            code: 'tool.intent.invalid_value',
            message: 'PDF orientation must be portrait or landscape.',
            severity: VerificationSeverity.blocking,
            fieldPath: 'toolIntents.$intentId.arguments.orientation',
            subject: 'generate_report_pdf',
          ),
        );
      }
    }

    if (paperSize != null && paperSize.toString().trim().isEmpty) {
      issues.add(
        VerificationIssue(
          code: 'tool.intent.invalid_value',
          message: 'PDF paper size cannot be empty when provided.',
          severity: VerificationSeverity.blocking,
          fieldPath: 'toolIntents.$intentId.arguments.paper_size',
          subject: 'generate_report_pdf',
        ),
      );
    }

    return issues;
  }

  Map<String, Map<String, Object?>> _readObjectMap(Object? value) {
    if (value is! Map) {
      return const <String, Map<String, Object?>>{};
    }
    return value.map(
      (key, childValue) => MapEntry(
        key.toString(),
        childValue is Map
            ? Map<String, Object?>.from(childValue)
            : <String, Object?>{},
      ),
    );
  }

  List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.map((item) => item.toString()).toList(growable: false);
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  bool _isIntegerLike(Object? value) {
    if (value is int) {
      return true;
    }
    if (value is double) {
      return value == value.truncateToDouble();
    }
    return false;
  }

  bool _isBlankValue(Object? value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is List) {
      return value.isEmpty;
    }
    if (value is Map) {
      return value.isEmpty;
    }
    return false;
  }
}
