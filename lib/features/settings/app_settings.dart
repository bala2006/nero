class NeroSettings {
  const NeroSettings({
    required this.sarvamApiKey,
    required this.selectedModelId,
  });

  final String sarvamApiKey;
  final String selectedModelId;

  factory NeroSettings.defaults() {
    return const NeroSettings(
      sarvamApiKey: 'sk_1rz4pjqr_Ua19zFlZO1hBo4aVuUfFiTGc',
      selectedModelId: 'sarvam-105b',
    );
  }

  NeroSettings copyWith({
    String? sarvamApiKey,
    String? selectedModelId,
  }) {
    return NeroSettings(
      sarvamApiKey: sarvamApiKey ?? this.sarvamApiKey,
      selectedModelId: selectedModelId ?? this.selectedModelId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sarvamApiKey': sarvamApiKey,
        'selectedModelId': selectedModelId,
      };

  factory NeroSettings.fromJson(Map<String, dynamic> json) {
    final defaults = NeroSettings.defaults();
    return NeroSettings(
      sarvamApiKey: json['sarvamApiKey']?.toString() ?? defaults.sarvamApiKey,
      selectedModelId:
          json['selectedModelId']?.toString() ?? defaults.selectedModelId,
    );
  }
}
