import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;

import '../audit/application/audit_log_store.dart';
import '../audit/domain/app_capability.dart';
import '../audit/domain/audit_log_entry.dart';
import '../runtime/domain/agent_policy.dart';
import '../../platform/database/app_database.dart';
import '../../platform/database/app_metadata_store.dart';
import '../../platform/storage/json_file_store.dart';
import 'advanced_settings.dart';
import 'app_settings.dart';
import 'reasoning_settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({
    AppDatabase? database,
    JsonFileStore? store,
    AuditLogStore? auditLogStore,
    AppMetadataStore? appMetadataStore,
  })  : _store = store ?? JsonFileStore.system(),
        _database = database ?? AppDatabase.instance,
        _auditLogStore = auditLogStore ?? AuditLogStore(),
        _metadataStore = appMetadataStore ?? AppMetadataStore(),
        _state = NeroSettings.defaults();

  static const String _storageFileName = 'app_settings.json';

  final AppDatabase _database;
  final JsonFileStore _store;
  final AuditLogStore _auditLogStore;
  final AppMetadataStore _metadataStore;
  NeroSettings _state;
  AdvancedSettings _advanced = const AdvancedSettings();
  bool _loaded = false;
  String? _error;
  Timer? _apiKeyPersistDebounce;
  bool _hasPendingApiKeyChange = false;

  NeroSettings get state => _state;

  /// Reasoning, agent-mode, approval and budget preferences.
  AdvancedSettings get advanced => _advanced;

  bool get isLoaded => _loaded;
  String? get error => _error;

  Future<void> load() async {
    try {
      await _migrateLegacyJsonIfNeeded();
      final defaults = NeroSettings.defaults();
      final row = await (_database.select(_database.appSettingsEntries)
            ..where((table) => table.id.equals(1)))
          .getSingleOrNull();
      final normalized = row == null
          ? defaults
          : defaults.copyWith(
              azureApiKey: row.azureApiKey.trim().isEmpty
                  ? defaults.azureApiKey
                  : row.azureApiKey,
              selectedModelId: row.selectedModelId.trim().isEmpty
                  ? defaults.selectedModelId
                  : row.selectedModelId,
            );
      _state = normalized;
      _advanced = await _loadAdvancedSettings();
      if (row == null) {
        await _persist();
      }
      _loaded = true;
      _error = null;
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
    }
  }

  Future<void> setAzureApiKey(String apiKey) async {
    _state = _state.copyWith(azureApiKey: apiKey.trim());
    _hasPendingApiKeyChange = true;
    _scheduleApiKeyPersist();
  }

  Future<void> setSelectedModelId(String modelId) async {
    _state = _state.copyWith(selectedModelId: modelId);
    await _persist();
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.settingsModel.key,
      title: AppCapabilities.settingsModel.label,
      detail: 'Selected model: $modelId',
      status: AuditLogStatus.success,
    );
    notifyListeners();
  }

  Future<void> setReasoningPreferences(ReasoningPreferences preferences) async {
    _advanced = _advanced.copyWith(reasoning: preferences);
    await _persistAdvanced();
    notifyListeners();
  }

  Future<void> setAgentMode(AgentMode mode) async {
    _advanced = _advanced.copyWith(agentMode: mode);
    await _persistAdvanced();
    notifyListeners();
  }

  Future<void> setApprovalPolicy(ApprovalPolicy policy) async {
    _advanced = _advanced.copyWith(approvalPolicy: policy);
    await _persistAdvanced();
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.settingsApprovalPolicy.key,
      title: AppCapabilities.settingsApprovalPolicy.label,
      detail: 'Approval policy set to ${policy.label}.',
      status: AuditLogStatus.success,
    );
    notifyListeners();
  }

  Future<void> setRunBudget(RunBudget budget) async {
    _advanced = _advanced.copyWith(budget: budget);
    await _persistAdvanced();
    notifyListeners();
  }

  Future<void> setToolApprovalOverride(
    String toolName,
    ApprovalPolicy policy,
  ) async {
    _advanced = _advanced.withToolApprovalOverride(toolName, policy);
    await _persistAdvanced();
    notifyListeners();
  }

  Future<void> clearToolApprovalOverride(String toolName) async {
    _advanced = _advanced.withoutToolApprovalOverride(toolName);
    await _persistAdvanced();
    notifyListeners();
  }

  Future<AdvancedSettings> _loadAdvancedSettings() async {
    final raw = await _metadataStore.read(AdvancedSettings.storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const AdvancedSettings();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AdvancedSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return AdvancedSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return const AdvancedSettings();
  }

  Future<void> _persistAdvanced() async {
    await _metadataStore.write(
      AdvancedSettings.storageKey,
      jsonEncode(_advanced.toJson()),
    );
  }

  Future<void> reset() async {
    _apiKeyPersistDebounce?.cancel();
    _apiKeyPersistDebounce = null;
    _hasPendingApiKeyChange = false;
    _state = NeroSettings.defaults();
    _advanced = const AdvancedSettings();
    await _persist();
    await _persistAdvanced();
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.settingsReset.key,
      title: AppCapabilities.settingsReset.label,
      detail: 'Cloud settings reset to defaults.',
      status: AuditLogStatus.success,
    );
    notifyListeners();
  }

  Future<void> _persist() async {
    await _database.into(_database.appSettingsEntries).insertOnConflictUpdate(
          AppSettingsEntriesCompanion(
            id: const drift.Value(1),
            azureApiKey: drift.Value(_state.azureApiKey),
            selectedModelId: drift.Value(_state.selectedModelId),
          ),
        );
  }

  void _scheduleApiKeyPersist() {
    _apiKeyPersistDebounce?.cancel();
    final apiKeySnapshot = _state.azureApiKey;
    _apiKeyPersistDebounce = Timer(const Duration(milliseconds: 240), () {
      unawaited(_persistApiKeySnapshot(apiKeySnapshot));
    });
  }

  Future<void> _persistApiKeySnapshot(String apiKeySnapshot) async {
    if (!_hasPendingApiKeyChange || _state.azureApiKey != apiKeySnapshot) {
      return;
    }
    _hasPendingApiKeyChange = false;
    await _persist();
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.settingsApiKey.key,
      title: AppCapabilities.settingsApiKey.label,
      detail: 'Azure AI key updated on device.',
      status: AuditLogStatus.success,
    );
    notifyListeners();
  }

  Future<void> _migrateLegacyJsonIfNeeded() async {
    final existing = await (_database.select(_database.appSettingsEntries)
          ..where((table) => table.id.equals(1)))
        .getSingleOrNull();
    if (existing != null) {
      return;
    }

    final json = await _store.readObject(_storageFileName);
    final loaded = NeroSettings.fromJson(json);
    await _database.into(_database.appSettingsEntries).insert(
          AppSettingsEntriesCompanion(
            id: const drift.Value(1),
            azureApiKey: drift.Value(loaded.azureApiKey),
            selectedModelId: drift.Value(loaded.selectedModelId),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
  }

  @override
  void dispose() {
    _apiKeyPersistDebounce?.cancel();
    super.dispose();
  }
}
