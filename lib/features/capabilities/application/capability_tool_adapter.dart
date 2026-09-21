import '../../chat/application/sarvam_api_client.dart';
import '../domain/capability_registry.dart';
import 'capability_catalog.dart';

class CapabilityToolAdapter {
  const CapabilityToolAdapter._();

  static SarvamToolDefinition toSarvamToolDefinition(
    CapabilityDefinition capability,
  ) {
    final descriptor = capability.toolDescriptor;
    if (descriptor == null) {
      throw ArgumentError.value(
        capability.key,
        'capability',
        'Capability is not model-exposed as a tool.',
      );
    }
    return SarvamToolDefinition(
      name: descriptor.name,
      description: descriptor.description,
      parameters: Map<String, dynamic>.from(descriptor.parameters),
    );
  }

  static List<SarvamToolDefinition> modelVisibleToolDefinitions({
    CapabilityCatalog? catalog,
  }) {
    final effective = catalog ?? CapabilityCatalog.instance;
    return List<SarvamToolDefinition>.unmodifiable(
      effective
          .visibleToModel()
          .where((capability) => capability.toolDescriptor != null)
          .map(toSarvamToolDefinition),
    );
  }
}
