import '../providers/azure_ai_config.dart';
import 'nero_model_catalog.dart';

class NeroSettings {
  const NeroSettings({
    required this.azureApiKey,
    required this.selectedModelId,
    this.azureBaseUrl = '',
  });

  /// Azure AI key, sent to the Responses API as the `api-key` header.
  ///
  /// Previously there was a second `sarvamApiKey` field for the retired
  /// provider; it is gone and the Azure key is the only credential.
  final String azureApiKey;

  final String selectedModelId;

  /// Azure AI endpoint, e.g. `https://<resource>.openai.azure.com/openai/v1`.
  /// The client appends `/responses` when it isn't already present.
  final String azureBaseUrl;

  factory NeroSettings.defaults() {
    // Azure AI is the only provider. Its endpoint and key are hardcoded in
    // AzureAiConfig; see that file to set them.
    return const NeroSettings(
      azureApiKey: AzureAiConfig.apiKey,
      selectedModelId: NeroModelCatalog.azureLunaModelId,
      azureBaseUrl: AzureAiConfig.baseUrl,
    );
  }

  NeroSettings copyWith({
    String? azureApiKey,
    String? selectedModelId,
    String? azureBaseUrl,
  }) {
    return NeroSettings(
      azureApiKey: azureApiKey ?? this.azureApiKey,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      azureBaseUrl: azureBaseUrl ?? this.azureBaseUrl,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'azureApiKey': azureApiKey,
        'selectedModelId': selectedModelId,
        'azureBaseUrl': azureBaseUrl,
      };

  factory NeroSettings.fromJson(Map<String, dynamic> json) {
    final defaults = NeroSettings.defaults();
    // Legacy JSON files stored the key under `sarvamApiKey`; read both keys so
    // an upgrade keeps the user's credential.
    final legacyKey = json['sarvamApiKey']?.toString();
    final azureKey = json['azureApiKey']?.toString();
    return NeroSettings(
      azureApiKey:
          (azureKey == null || azureKey.isEmpty) && legacyKey != null
              ? legacyKey
              : azureKey ?? defaults.azureApiKey,
      selectedModelId:
          json['selectedModelId']?.toString() ?? defaults.selectedModelId,
      azureBaseUrl:
          json['azureBaseUrl']?.toString() ?? defaults.azureBaseUrl,
    );
  }
}
