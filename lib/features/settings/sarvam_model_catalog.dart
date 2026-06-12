class SarvamModelInfo {
  const SarvamModelInfo({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.contextWindowTokens,
  });

  final String id;
  final String name;
  final String subtitle;
  final int contextWindowTokens;
}

class SarvamModelCatalog {
  const SarvamModelCatalog();

  static const List<SarvamModelInfo> _models = <SarvamModelInfo>[
    SarvamModelInfo(
      id: 'sarvam-30b',
      name: 'Sarvam 30B',
      subtitle: 'Balanced cloud chat model for general use.',
      contextWindowTokens: 64000,
    ),
    SarvamModelInfo(
      id: 'sarvam-105b',
      name: 'Sarvam 105B',
      subtitle: 'Highest quality model for reasoning, coding, and generation.',
      contextWindowTokens: 128000,
    ),
    SarvamModelInfo(
      id: 'sarvam-m',
      name: 'Sarvam-M',
      subtitle: 'Legacy model kept for compatibility.',
      contextWindowTokens: 32000,
    ),
  ];

  List<SarvamModelInfo> list() => _models;

  SarvamModelInfo byId(String id) {
    return _models.firstWhere(
      (model) => model.id == id,
      orElse: () => _models.first,
    );
  }
}
