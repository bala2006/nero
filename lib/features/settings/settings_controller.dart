import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;

import '../audit/application/audit_log_store.dart';
import '../audit/domain/app_capability.dart';
import '../audit/domain/audit_log_entry.dart';
import '../../platform/database/app_database.dart';
import '../../platform/storage/json_file_store.dart';
import 'app_settings.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({
    AppDatabase? database,
    JsonFileStore? store,
    AuditLogStore? auditLogStore,
  })  : _store = store ?? JsonFileStore.system(),
        _database = database ?? AppDatabase.instance,
        _auditLogStore = auditLogStore ?? AuditLogStore(),
        _state = NeroSettings.defaults();

  static const String _storageFileName = 'app_settings.json';

  final AppDatabase _database;
  final JsonFileStore _store;
  final AuditLogStore _auditLogStore;
  NeroSettings _state;
  bool _loaded = false;
  String? _error;
  Timer? _apiKeyPersistDebounce;
  bool _hasPendingApiKeyChange = false;

  NeroSettings get state => _state;
  bool get isLoaded => _loaded;
  String? get error => _error;

  Future<void> load() async {
    try {
      await _migrateLegacyJsonIfNeeded();
      final defaults = NeroSettings.defaults();
      final row = await (_database.select(_database.appSettingsEntries)
            ..where((table) => table.id.equals(1)))
          .getSingleOrNull();
      final loaded = row == null
          ? defaults
          : NeroSettings(
              sarvamApiKey: row.sarvamApiKey,
              selectedModelId: row.selectedModelId,
            );
      final normalized = loaded.copyWith(
        sarvamApiKey: loaded.sarvamApiKey.trim().isEmpty
            ? defaults.sarvamApiKey
            : loaded.sarvamApiKey,
        selectedModelId: 'sarvam-105b',
      );
      _state = normalized;
      if (row == null || !_isSameSettings(loaded, normalized)) {
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

  Future<void> setSarvamApiKey(String apiKey) async {
    _state = _state.copyWith(sarvamApiKey: apiKey.trim());
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

  Future<void> reset() async {
    _apiKeyPersistDebounce?.cancel();
    _apiKeyPersistDebounce = null;
    _hasPendingApiKeyChange = false;
    _state = NeroSettings.defaults();
    await _persist();
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
            sarvamApiKey: drift.Value(_state.sarvamApiKey),
            selectedModelId: drift.Value(_state.selectedModelId),
          ),
        );
  }

  void _scheduleApiKeyPersist() {
    _apiKeyPersistDebounce?.cancel();
    final apiKeySnapshot = _state.sarvamApiKey;
    _apiKeyPersistDebounce = Timer(const Duration(milliseconds: 240), () {
      unawaited(_persistApiKeySnapshot(apiKeySnapshot));
    });
  }

  Future<void> _persistApiKeySnapshot(String apiKeySnapshot) async {
    if (!_hasPendingApiKeyChange || _state.sarvamApiKey != apiKeySnapshot) {
      return;
    }
    _hasPendingApiKeyChange = false;
    await _persist();
    await _auditLogStore.record(
      capabilityKey: AppCapabilities.settingsApiKey.key,
      title: AppCapabilities.settingsApiKey.label,
      detail: 'Sarvam API key updated on device.',
      status: AuditLogStatus.success,
    );
    notifyListeners();
  }

  bool _isSameSettings(NeroSettings left, NeroSettings right) {
    return left.sarvamApiKey == right.sarvamApiKey &&
        left.selectedModelId == right.selectedModelId;
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
            sarvamApiKey: drift.Value(loaded.sarvamApiKey),
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
