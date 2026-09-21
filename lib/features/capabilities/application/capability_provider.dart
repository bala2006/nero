import '../domain/capability_registry.dart';

/// A source of capabilities.
///
/// Before this existed the capability list was a hard-coded `static const`
/// list, so nothing could add a tool at runtime. MCP servers, the on-device
/// sandbox and any future plugin register a provider instead.
abstract class CapabilityProvider {
  /// Stable identifier, used to replace a provider on refresh.
  String get providerId;

  /// Bumped by the provider whenever [capabilities] would return something
  /// different, so the catalog knows to rebuild its merged view.
  int get revision;

  /// Human-readable source label shown in the capabilities browser.
  String get sourceLabel;

  List<CapabilityDefinition> capabilities();
}

/// Built-in Nero tools (web, documents, files, packaging).
class BuiltInCapabilityProvider implements CapabilityProvider {
  const BuiltInCapabilityProvider();

  @override
  String get providerId => 'builtin';

  @override
  int get revision => 1;

  @override
  String get sourceLabel => 'Nero';

  @override
  List<CapabilityDefinition> capabilities() => CapabilityRegistry.all;
}
