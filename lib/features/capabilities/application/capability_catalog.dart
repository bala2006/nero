import 'package:flutter/foundation.dart';

import '../domain/capability_registry.dart';
import 'capability_provider.dart';

/// Merged view of every registered [CapabilityProvider].
///
/// This is the single source of truth for the model's tool list and for the
/// tool-name to capability lookup used by the executors. Built-in tools are
/// registered by default; MCP servers and the sandbox add providers.
class CapabilityCatalog extends ChangeNotifier {
  CapabilityCatalog({List<CapabilityProvider> providers = const []}) {
    for (final provider in providers) {
      _providers[provider.providerId] = provider;
    }
  }

  /// Process-wide catalog used by production code.
  static final CapabilityCatalog instance = CapabilityCatalog(
    providers: const <CapabilityProvider>[BuiltInCapabilityProvider()],
  );

  final Map<String, CapabilityProvider> _providers =
      <String, CapabilityProvider>{};

  List<CapabilityDefinition>? _mergedCache;
  List<String>? _toolNameCache;
  List<Map<String, Object?>>? _toolPayloadCache;
  int _revision = 0;

  /// Monotonic revision, incremented on every change. Callers that cache
  /// derived data (the tool selector does) key their cache on this.
  int get revision => _revision;

  /// Providers currently registered, in registration order.
  List<CapabilityProvider> get providers =>
      List<CapabilityProvider>.unmodifiable(_providers.values);

  void register(CapabilityProvider provider) {
    _providers[provider.providerId] = provider;
    _invalidate();
  }

  void unregister(String providerId) {
    if (_providers.remove(providerId) == null) {
      return;
    }
    _invalidate();
  }

  /// Signals that a provider's contents changed without re-registering it.
  /// Providers may call this after their own `revision` was bumped.
  void notifyProviderChanged(String providerId) {
    if (!_providers.containsKey(providerId)) {
      return;
    }
    _invalidate();
  }

  /// Every capability from every provider, de-duplicated by key (later
  /// providers win, so a user-configured MCP tool can shadow a built-in).
  List<CapabilityDefinition> get all {
    final cached = _mergedCache;
    if (cached != null) {
      return cached;
    }
    final byKey = <String, CapabilityDefinition>{};
    for (final provider in _providers.values) {
      for (final capability in provider.capabilities()) {
        byKey[capability.key] = capability;
      }
    }
    return _mergedCache = List<CapabilityDefinition>.unmodifiable(
      byKey.values,
    );
  }

  bool get isEmpty => all.isEmpty;

  List<CapabilityDefinition> visibleToModel() {
    return List<CapabilityDefinition>.unmodifiable(
      all.where((capability) => capability.exposedToModel),
    );
  }

  List<CapabilityDefinition> preferredForModel() {
    return List<CapabilityDefinition>.unmodifiable(
      all.where(
        (capability) =>
            capability.modelExposure == CapabilityModelExposure.preferred,
      ),
    );
  }

  List<String> modelToolNames() {
    final cached = _toolNameCache;
    if (cached != null) {
      return cached;
    }
    return _toolNameCache = List<String>.unmodifiable(
      visibleToModel()
          .map((capability) => capability.toolName)
          .whereType<String>(),
    );
  }

  List<Map<String, Object?>> modelToolPayloads() {
    final cached = _toolPayloadCache;
    if (cached != null) {
      return cached;
    }
    return _toolPayloadCache = List<Map<String, Object?>>.unmodifiable(
      visibleToModel()
          .map((capability) => capability.toolDescriptor)
          .whereType<CapabilityToolDescriptor>()
          .map((descriptor) => descriptor.toMap()),
    );
  }

  List<CapabilityDefinition> singleUseCapabilities() {
    return List<CapabilityDefinition>.unmodifiable(
      all.where((capability) => capability.singleUse),
    );
  }

  CapabilityDefinition? byKey(String key) {
    for (final capability in all) {
      if (capability.key == key) {
        return capability;
      }
    }
    return null;
  }

  CapabilityDefinition? byToolName(String toolName) {
    for (final capability in all) {
      if (capability.toolName == toolName) {
        return capability;
      }
    }
    return null;
  }

  /// The provider that owns [toolName], or null when unknown.
  CapabilityProvider? providerForToolName(String toolName) {
    for (final provider in _providers.values) {
      for (final capability in provider.capabilities()) {
        if (capability.toolName == toolName) {
          return provider;
        }
      }
    }
    return null;
  }

  void _invalidate() {
    _mergedCache = null;
    _toolNameCache = null;
    _toolPayloadCache = null;
    _revision += 1;
    notifyListeners();
  }
}
