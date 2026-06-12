import '../../chat/application/sarvam_api_client.dart';
import '../domain/capability_registry.dart';

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

  static List<SarvamToolDefinition> modelVisibleToolDefinitions() {
    return List<SarvamToolDefinition>.unmodifiable(
      CapabilityRegistry.visibleToModel()
          .where((capability) => capability.toolDescriptor != null)
          .map(toSarvamToolDefinition),
    );
  }
}
