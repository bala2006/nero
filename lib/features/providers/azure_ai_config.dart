/// Azure AI (Microsoft Foundry Models) configuration, baked into the build.
///
/// Nero runs entirely on Azure AI with the `gpt-5.6-luna` deployment. Fill in
/// [baseUrl] and [apiKey] below with your own Azure resource values.
///
/// [baseUrl] is the OpenAI-compatible v1 endpoint of your Azure resource; the
/// client appends `/responses` (the Responses API path Azure recommends for
/// reasoning plus function tools).
class AzureAiConfig {
  AzureAiConfig._();

  /// Azure AI Foundry Responses endpoint of the Nero resource.
  static const String baseUrl =
      'https://tejaswinikanuri68-9812--resource.services.ai.azure.com/openai/v1/responses';

  /// Azure AI key, sent to the Responses API as the `api-key` header.
  ///
  /// Left blank on purpose: the key is entered in the app's Cloud Settings and
  /// stored on-device, so no credential is compiled into the binary.
  static const String apiKey = '';

  /// Azure deployment name for the model.
  static const String deploymentId = 'gpt-5.6-luna';

  /// gpt-5.6 models default to `medium`; Nero runs them at high effort.
  static const String reasoningEffort = 'high';

  /// Headroom for reasoning tokens plus visible output.
  static const int maxOutputTokens = 25000;

  static bool get hasBaseUrl => baseUrl.trim().isNotEmpty;

  static bool get hasApiKey => apiKey.trim().isNotEmpty;
}
