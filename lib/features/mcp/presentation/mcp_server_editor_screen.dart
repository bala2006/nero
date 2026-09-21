import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/widgets.dart';
import '../application/mcp_registry.dart';
import '../domain/mcp_connection_state.dart';
import '../domain/mcp_server_config.dart';

/// Creates or edits one MCP server, with a live "Test connection" check.
class McpServerEditorScreen extends StatefulWidget {
  const McpServerEditorScreen({
    super.key,
    required this.registry,
    this.existing,
  });

  final McpRegistry registry;

  /// Null when adding a new server.
  final McpServerConfig? existing;

  @override
  State<McpServerEditorScreen> createState() => _McpServerEditorScreenState();
}

class _McpServerEditorScreenState extends State<McpServerEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  late final TextEditingController _headersController;
  late final TextEditingController _blockedController;
  late final TextEditingController _allowedController;

  late McpTransportKind _transport;
  late bool _enabled;
  late bool _autoApprove;
  late int _timeoutMs;

  bool _testing = false;
  bool _saving = false;
  String? _testError;
  String? _testSuccess;
  String? _urlError;
  String? _nameError;
  String? _headersError;

  static const List<int> _timeoutOptions = <int>[10000, 20000, 45000, 90000];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.displayName ?? '');
    _urlController = TextEditingController(text: existing?.url ?? '');
    _tokenController = TextEditingController(text: existing?.authToken ?? '');
    _headersController = TextEditingController(
      text: _encodeHeaders(existing?.headers ?? const <String, String>{}),
    );
    _allowedController = TextEditingController(
      text: (existing?.allowedToolNames ?? const <String>[]).join(', '),
    );
    _blockedController = TextEditingController(
      text: (existing?.blockedToolNames ?? const <String>[]).join(', '),
    );
    _transport = existing?.transport ?? McpTransportKind.streamableHttp;
    _enabled = existing?.enabled ?? true;
    _autoApprove = existing?.autoApprove ?? false;
    _timeoutMs = existing?.timeoutMs ?? 20000;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _headersController.dispose();
    _allowedController.dispose();
    _blockedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const NeroBackdrop(),
          SafeArea(
            child: Column(
              children: <Widget>[
                NeroTopBar(
                  title: isEditing ? 'Edit server' : 'Add MCP server',
                  subtitle: 'Remote Model Context Protocol server',
                  onBackTap: () => Navigator.of(context).maybePop(),
                  actions: <Widget>[
                    HeaderIconButton(
                      icon: Icons.check_rounded,
                      semanticLabel: 'Save server',
                      onTap: _saving ? () {} : _save,
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    children: <Widget>[
                      _buildConnectionCard(),
                      const SizedBox(height: 12),
                      _buildAuthCard(),
                      const SizedBox(height: 12),
                      _buildPolicyCard(),
                      const SizedBox(height: 12),
                      if (_testError != null) ...<Widget>[
                        InlineBanner(
                          message: _testError!,
                          tone: InlineBannerTone.error,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_testSuccess != null) ...<Widget>[
                        InlineBanner(
                          message: _testSuccess!,
                          tone: InlineBannerTone.success,
                          icon: Icons.check_circle_rounded,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _SecondaryButton(
                              label: _testing
                                  ? 'Testing…'
                                  : 'Test connection',
                              icon: Icons.bolt_rounded,
                              busy: _testing,
                              onTap: _testing ? null : _test,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PrimaryButton(
                              label: isEditing ? 'Save changes' : 'Add server',
                              icon: Icons.add_rounded,
                              busy: _saving,
                              onTap: _saving ? null : _save,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return SectionCard(
      title: 'Connection',
      subtitle: 'Where Nero reaches this server.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Field(
            controller: _nameController,
            label: 'Display name',
            hint: 'GitHub',
            errorText: _nameError,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _urlController,
            label: 'Server URL',
            hint: 'https://example.com/mcp',
            keyboardType: TextInputType.url,
            errorText: _urlError,
          ),
          const SizedBox(height: 14),
          Text(
            'Transport',
            style: AppTextStyles.caption.copyWith(fontSize: 11.2),
          ),
          const SizedBox(height: 8),
          RadioGroup<McpTransportKind>(
            groupValue: _transport,
            onChanged: (value) {
              if (value != null) {
                _setTransport(value);
              }
            },
            child: Column(
              children: <Widget>[
                for (final kind in McpTransportKind.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: NeroTile(
                      title: kind.label,
                      subtitle: kind.description,
                      icon: kind == McpTransportKind.streamableHttp
                          ? Icons.swap_horiz_rounded
                          : Icons.stream_rounded,
                      dense: true,
                      trailing: Radio<McpTransportKind>(value: kind),
                      onTap: () => _setTransport(kind),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: _timeoutMs,
            dropdownColor: AppColors.dropdownBackground,
            style: AppTextStyles.body.copyWith(fontSize: 13),
            decoration: _inputDecoration('Request timeout'),
            items: <DropdownMenuItem<int>>[
              for (final option in _timeoutOptions)
                DropdownMenuItem<int>(
                  value: option,
                  child: Text('${option ~/ 1000} seconds'),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _timeoutMs = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return SectionCard(
      title: 'Authentication',
      subtitle: 'Stored on this device only.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Field(
            controller: _tokenController,
            label: 'Bearer token',
            hint: 'Optional',
            obscureText: true,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _headersController,
            label: 'Extra headers',
            hint: 'X-Org: acme\nX-Env: prod',
            maxLines: 3,
            errorText: _headersError,
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard() {
    return SectionCard(
      title: 'Policy',
      subtitle: 'What Nero may do with this server.',
      child: Column(
        children: <Widget>[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
            title: Text(
              'Enabled',
              style: AppTextStyles.body.copyWith(fontSize: 13),
            ),
            subtitle: Text(
              'When off, its tools are removed from the model immediately.',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _autoApprove,
            onChanged: (value) => setState(() => _autoApprove = value),
            title: Text(
              'Auto-approve tool calls',
              style: AppTextStyles.body.copyWith(fontSize: 13),
            ),
            subtitle: Text(
              'Skip the approval gate for this server. Individual tools can '
              'still be set to always ask.',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ),
          const SizedBox(height: 6),
          _Field(
            controller: _allowedController,
            label: 'Allow only these tools',
            hint: 'Leave empty to allow every discovered tool',
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _blockedController,
            label: 'Always block',
            hint: 'Comma separated tool names',
          ),
        ],
      ),
    );
  }

  // ---- actions ------------------------------------------------------------

  /// Changing the transport invalidates any previous connection test.
  void _setTransport(McpTransportKind transport) {
    if (_transport == transport) {
      return;
    }
    setState(() {
      _transport = transport;
      _testError = null;
      _testSuccess = null;
    });
  }

  McpServerConfig? _buildConfig() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final headersResult = _parseHeaders(_headersController.text);
    setState(() {
      _nameError = name.isEmpty ? 'Give this server a name.' : null;
      _urlError = _validateUrl(url);
      _headersError = headersResult.error;
    });
    if (_nameError != null || _urlError != null || _headersError != null) {
      return null;
    }
    final existing = widget.existing;
    return McpServerConfig(
      id: existing?.id ?? '',
      displayName: name,
      url: url,
      transport: _transport,
      headers: headersResult.headers,
      authToken: _tokenController.text.trim(),
      enabled: _enabled,
      autoApprove: _autoApprove,
      timeoutMs: _timeoutMs,
      allowedToolNames: _splitNames(_allowedController.text),
      blockedToolNames: _splitNames(_blockedController.text),
    );
  }

  Future<void> _test() async {
    final config = _buildConfig();
    if (config == null) {
      return;
    }
    setState(() {
      _testing = true;
      _testError = null;
      _testSuccess = null;
    });
    final McpConnectionState state = await widget.registry.testConnection(
      config,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _testing = false;
      if (state.isConnected) {
        _testSuccess =
            'Connected to ${state.serverName ?? 'the server'} '
            '(protocol ${state.protocolVersion ?? 'unknown'}) · '
            '${state.toolCount} tool(s) discovered.';
      } else {
        _testError = state.error ?? 'Could not connect to this server.';
      }
    });
  }

  Future<void> _save() async {
    final config = _buildConfig();
    if (config == null) {
      return;
    }
    setState(() => _saving = true);
    final registry = widget.registry;
    final McpServerConfig saved;
    if (widget.existing == null) {
      saved = await registry.addServer(config);
    } else {
      await registry.updateServer(config);
      saved = config;
    }
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (saved.enabled) {
      // Discover tools right away so the user sees the result of adding a
      // server instead of having to press refresh.
      await registry.refresh(saved.id);
    } else {
      await registry.disconnect(saved.id);
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  String? _validateUrl(String url) {
    if (url.isEmpty) {
      return 'A server URL is required.';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return 'That is not a valid URL.';
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return 'Use an http or https URL.';
    }
    if (uri.host.isEmpty) {
      return 'The URL needs a host.';
    }
    return null;
  }

  List<String> _splitNames(String value) {
    return value
        .split(RegExp(r'[,\n]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _encodeHeaders(Map<String, String> headers) {
    return headers.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
  }

  ({Map<String, String> headers, String? error}) _parseHeaders(String raw) {
    final headers = <String, String>{};
    for (final line in raw.split(RegExp(r'[\n]'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final separator = trimmed.indexOf(':');
      if (separator <= 0) {
        return (
          headers: const <String, String>{},
          error: 'Header lines must look like "Name: value".',
        );
      }
      final name = trimmed.substring(0, separator).trim();
      final value = trimmed.substring(separator + 1).trim();
      if (name.isEmpty) {
        return (
          headers: const <String, String>{},
          error: 'A header name is missing.',
        );
      }
      headers[name] = value;
    }
    return (headers: headers, error: null);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final int maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11.2)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: AppTextStyles.body.copyWith(fontSize: 13),
          decoration: _inputDecoration(hint).copyWith(errorText: errorText),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String? hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.hint.copyWith(fontSize: 12.4),
    filled: true,
    fillColor: AppColors.surfaceSoft,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderSoft),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderSoft),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.orange),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12.8)),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12.8)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.borderSoft),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
