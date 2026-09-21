/// Catalog of cloud models Nero can run on.
///
/// Renamed from the legacy `SarvamModelCatalog`: the app has run exclusively on
/// Azure AI (Microsoft Foundry Models) since the single-provider migration, and
/// the old name made every call site read backwards.
class NeroModelInfo {
  const NeroModelInfo({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.contextWindowTokens,
    this.providerId = NeroModelCatalog.azureProviderId,
  });

  final String id;
  final String name;
  final String subtitle;
  final int contextWindowTokens;

  /// Which cloud provider serves this model. See [NeroModelCatalog].
  final String providerId;
}

class NeroModelCatalog {
  const NeroModelCatalog();

  static const String azureProviderId = 'azure';

  /// Legacy identifier, retained only so persisted settings never break.
  static const String sarvamProviderId = 'sarvam';

  /// Azure AI (Microsoft Foundry Models) deployment name.
  static const String azureLunaModelId = 'gpt-5.6-luna';

  static const List<NeroModelInfo> _models = <NeroModelInfo>[
    NeroModelInfo(
      id: azureLunaModelId,
      name: 'GPT-5.6 Luna',
      subtitle:
          'Azure AI reasoning model running at high reasoning effort with tool calling.',
      contextWindowTokens: 1050000,
      providerId: azureProviderId,
    ),
  ];

  List<NeroModelInfo> list() => _models;

  NeroModelInfo byId(String id) {
    return _models.firstWhere(
      (model) => model.id == id,
      orElse: () => _models.first,
    );
  }

  /// Resolves which provider owns [modelId]. Azure deployments are matched
  /// case-insensitively because deployment names are user-defined.
  String providerIdFor(String modelId) {
    final normalized = modelId.trim().toLowerCase();
    for (final model in _models) {
      if (model.id.toLowerCase() == normalized) {
        return model.providerId;
      }
    }
    return sarvamProviderId;
  }

  bool isAzureModel(String modelId) =>
      providerIdFor(modelId) == azureProviderId;
}
