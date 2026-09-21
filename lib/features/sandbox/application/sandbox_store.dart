import 'dart:convert';

import '../../../platform/database/app_metadata_store.dart';
import '../domain/sandbox_models.dart';

/// Persists sandbox sessions and the permission policy.
class SandboxStore {
  SandboxStore({AppMetadataStore? metadataStore})
    : _metadataStore = metadataStore ?? AppMetadataStore();

  static const String sessionsKey = 'sandbox.sessions';
  static const String policyKey = 'sandbox.policy';

  final AppMetadataStore _metadataStore;

  Future<List<SandboxSession>> loadSessions() async {
    final raw = await _metadataStore.read(sessionsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <SandboxSession>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (item) => SandboxSession.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((session) => session.id.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {}
    return const <SandboxSession>[];
  }

  Future<void> saveSessions(List<SandboxSession> sessions) async {
    await _metadataStore.write(
      sessionsKey,
      jsonEncode(sessions.map((session) => session.toJson()).toList()),
    );
  }

  Future<SandboxPolicy> loadPolicy() async {
    final raw = await _metadataStore.read(policyKey);
    if (raw == null || raw.trim().isEmpty) {
      return const SandboxPolicy();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return SandboxPolicy.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return const SandboxPolicy();
  }

  Future<void> savePolicy(SandboxPolicy policy) async {
    await _metadataStore.write(policyKey, jsonEncode(policy.toJson()));
  }
}
