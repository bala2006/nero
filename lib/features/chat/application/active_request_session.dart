import '../../settings/app_settings.dart';

class ActiveRequestSession {
  String? _apiKey;
  NeroSettings? _settings;
  String? _prompt;
  List<String> _selectedTools = const <String>[];

  String? get apiKey => _apiKey;
  NeroSettings? get settings => _settings;
  String? get prompt => _prompt;
  List<String> get selectedTools => _selectedTools;

  void begin({
    required String apiKey,
    required NeroSettings settings,
    required String prompt,
  }) {
    _apiKey = apiKey;
    _settings = settings;
    _prompt = prompt;
    _selectedTools = const <String>[];
  }

  void clear() {
    _apiKey = null;
    _settings = null;
    _prompt = null;
    _selectedTools = const <String>[];
  }

  void clearSelectedTools() {
    _selectedTools = const <String>[];
  }

  void setSelectedTools(List<String> selectedTools) {
    _selectedTools = List<String>.unmodifiable(selectedTools);
  }
}
