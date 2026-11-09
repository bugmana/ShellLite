import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/auth_method.dart';
import '../models/server_profile.dart';
import '../providers/server_store.dart';
import '../services/key_parser.dart';
import '../theme/app_theme.dart';
import 'server_form/key_auth_section.dart';
import 'server_form/passphrase_section.dart';
import 'server_form/password_auth_section.dart';
import 'server_form/tmux_config_panel.dart';

class ServerFormScreen extends StatefulWidget {
  final ServerProfile? existingProfile;

  const ServerFormScreen({super.key, this.existingProfile});

  @override
  State<ServerFormScreen> createState() => _ServerFormScreenState();
}

class _ServerFormScreenState extends State<ServerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _moreOptions = ExpansibleController();

  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _keyController;
  late final TextEditingController _keyPassphraseController;
  late final TextEditingController _initialCommandController;
  late final TextEditingController _tmuxSessionNameController;

  AuthType _authType = AuthType.password;
  bool _obscureKey = false;
  bool _isKeyEncrypted = false;
  bool _isLoadingCredential = false;
  bool _persistSession = false;
  bool _submitted = false;
  String? _keyValidationError;
  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameController = TextEditingController(text: p?.displayName ?? '');
    _hostController = TextEditingController(text: p?.host ?? '');
    _portController = TextEditingController(
        text: p?.port.toString() ?? '${SSHConfig.defaultPort}');
    _usernameController = TextEditingController(text: p?.username ?? '');
    _passwordController = TextEditingController();
    _keyController = TextEditingController();
    _keyPassphraseController = TextEditingController();
    _initialCommandController =
        TextEditingController(text: p?.initialCommand ?? '');
    _tmuxSessionNameController =
        TextEditingController(text: p?.tmuxSessionName ?? '');
    _persistSession = p?.persistSession ?? false;

    if (p != null) {
      _authType = p.authMethod.type;
      _obscureKey = p.authMethod.type == AuthType.sshKey;
      _loadExistingCredential(p);
    }
  }

  Future<void> _loadExistingCredential(ServerProfile profile) async {
    setState(() => _isLoadingCredential = true);
    final store = context.read<ServerStore>();
    final cred = await store.getCredential(profile);
    if (mounted && cred != null) {
      if (profile.authMethod.type == AuthType.password) {
        _passwordController.text = cred;
      } else {
        _keyController.text = cred;
        _isKeyEncrypted = SSHKeyParser.isEncrypted(cred);
        final pass = await store.getKeyPassphrase(profile);
        if (pass != null) {
          _keyPassphraseController.text = pass;
        }
      }
    }
    if (mounted) {
      setState(() => _isLoadingCredential = false);
    }
  }

  @override
  void dispose() {
    _moreOptions.dispose();
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _keyController.dispose();
    _keyPassphraseController.dispose();
    _initialCommandController.dispose();
    _tmuxSessionNameController.dispose();
    super.dispose();
  }

  String _cleanKey(String val) {
    return val.trim().replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  void _validateKey(String val, [String? passphrase]) {
    final clean = _cleanKey(val);
    if (clean.isEmpty) {
      setState(() {
        _isKeyEncrypted = false;
        _keyValidationError = null;
      });
      return;
    }
    final isEnc = SSHKeyParser.isEncrypted(clean);
    setState(() {
      _isKeyEncrypted = isEnc;
    });
    try {
      final pass = passphrase ?? _keyPassphraseController.text;
      SSHKeyParser.parse(clean, passphrase: pass.isNotEmpty ? pass : null);
      setState(() => _keyValidationError = null);
    } catch (e) {
      setState(() => _keyValidationError =
          e.toString().replaceAll('SSHKeyException: ', ''));
    }
  }

  void _clearKey() {
    setState(() {
      _keyController.clear();
      _keyPassphraseController.clear();
      _obscureKey = false;
      _isKeyEncrypted = false;
      _keyValidationError = null;
    });
  }

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) {
      _moreOptions.expand();
      return;
    }

    String? keyPassphrase;
    if (_authType == AuthType.sshKey) {
      final key = _cleanKey(_keyController.text);
      keyPassphrase = _keyPassphraseController.text;
      try {
        SSHKeyParser.parse(key,
            passphrase: keyPassphrase.isNotEmpty ? keyPassphrase : null);
      } catch (e) {
        setState(() => _keyValidationError =
            e.toString().replaceAll('SSHKeyException: ', ''));
        return;
      }
    }

    final store = context.read<ServerStore>();
    final port =
        int.tryParse(_portController.text.trim()) ?? SSHConfig.defaultPort;
    final id = widget.existingProfile?.id ?? const Uuid().v4();
    final tag = StorageConfig.buildCredentialTag(id);
    final passphraseTag = (keyPassphrase != null && keyPassphrase.isNotEmpty)
        ? StorageConfig.buildKeyPassphraseTag(id)
        : null;

    final authMethod = _authType == AuthType.password
        ? PasswordAuth(credentialTag: tag)
        : SSHKeyAuth(privateKeyTag: tag, passphraseTag: passphraseTag);

    final initialCmd = _initialCommandController.text.trim();
    final tmuxSession = _tmuxSessionNameController.text.trim();

    final profile = ServerProfile(
      id: id,
      displayName: _nameController.text.trim().isEmpty
          ? _hostController.text.trim()
          : _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: port,
      username: _usernameController.text.trim(),
      authMethod: authMethod,
      initialCommand: initialCmd.isNotEmpty ? initialCmd : null,
      persistSession: _persistSession,
      tmuxSessionName: tmuxSession.isNotEmpty ? tmuxSession : null,
    );

    final credential = _authType == AuthType.password
        ? _passwordController.text
        : _cleanKey(_keyController.text);

    if (widget.existingProfile == null) {
      await store.addProfile(
        profile,
        credential: credential,
        keyPassphrase: keyPassphrase,
      );
    } else {
      await store.updateProfile(
        profile,
        newCredential: credential.isNotEmpty ? credential : null,
        newKeyPassphrase: keyPassphrase,
        clearKeyPassphrase: keyPassphrase == null || keyPassphrase.isEmpty,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProfile != null;
    final theme = context.appTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit server' : 'New server'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: theme.primaryAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoadingCredential
          ? Center(child: CircularProgressIndicator(color: theme.primaryAccent))
          : Form(
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Server Details Section ─────────────────────────────
                      _buildSectionHeader('Server', theme),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                            labelText: 'Host', hintText: '192.168.1.10'),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Host is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'e.g. root or ubuntu',
                          prefixIcon:
                              Icon(Icons.person_outline_rounded, size: 20),
                        ),
                        autocorrect: false,
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Username is required'
                            : null,
                      ),

                      const SizedBox(height: 24),

                      // ── Authentication Section ─────────────────────────────
                      _buildSectionHeader('Authentication', theme),
                      const SizedBox(height: 10),
                      SegmentedButton<AuthType>(
                        segments: const [
                          ButtonSegment(
                            value: AuthType.password,
                            label: Text('Password'),
                            icon: Icon(Icons.lock_outline_rounded, size: 18),
                          ),
                          ButtonSegment(
                            value: AuthType.sshKey,
                            label: Text('SSH key'),
                            icon: Icon(Icons.key_rounded, size: 18),
                          ),
                        ],
                        selected: {_authType},
                        onSelectionChanged: (set) {
                          setState(() {
                            _authType = set.first;
                            _keyValidationError = null;
                          });
                        },
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: theme.primaryAccent,
                          selectedForegroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_authType == AuthType.password)
                        PasswordAuthSection(
                          controller: _passwordController,
                          isEditing: isEditing,
                          hasStoredPassword: isEditing &&
                              widget.existingProfile?.authMethod.type ==
                                  AuthType.password,
                          theme: theme,
                        )
                      else ...[
                        KeyAuthSection(
                          keyController: _keyController,
                          isEditing: isEditing,
                          hasStoredKey: isEditing &&
                              widget.existingProfile?.authMethod.type ==
                                  AuthType.sshKey,
                          obscureKey: _obscureKey,
                          onToggleObscureKey: () =>
                              setState(() => _obscureKey = !_obscureKey),
                          onClearKey: _clearKey,
                          onKeyChanged: (val) {
                            _validateKey(val);
                            setState(() {});
                          },
                          theme: theme,
                        ),
                        PassphraseSection(
                          controller: _keyPassphraseController,
                          isEditing: isEditing,
                          isKeyEncrypted: _isKeyEncrypted,
                          hasStoredPassphrase: isEditing &&
                              widget.existingProfile?.authMethod
                                  is SSHKeyAuth &&
                              (widget.existingProfile!.authMethod as SSHKeyAuth)
                                  .isPassphraseProtected,
                          validationError: _keyValidationError,
                          onChanged: (val) =>
                              _validateKey(_keyController.text, val),
                          onClear: () => _validateKey(_keyController.text),
                          theme: theme,
                        ),
                      ],

                      const SizedBox(height: 24),

                      ExpansionTile(
                        controller: _moreOptions,
                        title: const Text('More options'),
                        maintainState: true,
                        childrenPadding: const EdgeInsets.only(
                          top: AppSpacing.lg,
                          bottom: AppSpacing.sm,
                        ),
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name (optional)',
                              hintText: 'e.g. Production Web',
                              prefixIcon:
                                  Icon(Icons.label_outline_rounded, size: 20),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _portController,
                            decoration:
                                const InputDecoration(labelText: 'Port'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final port = int.tryParse(value ?? '');
                              return port == null || port < 1 || port > 65535
                                  ? 'Enter a port from 1 to 65535'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // ── Persistent Session (tmux) Section ───────────────────
                          _buildSectionHeader('Keep session (tmux)', theme),
                          const SizedBox(height: 8),
                          TmuxConfigPanel(
                            persistSession: _persistSession,
                            onPersistChanged: (val) =>
                                setState(() => _persistSession = val),
                            sessionNameController: _tmuxSessionNameController,
                            theme: theme,
                          ),

                          const SizedBox(height: 24),

                          // ── Startup Command Section ─────────────────────────────
                          _buildSectionHeader('Startup', theme),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: const Key('initialCommandField'),
                            controller: _initialCommandController,
                            decoration: InputDecoration(
                              labelText: 'Startup command',
                              hintText: 'e.g. htop or cd /var/www',
                              helperText: _persistSession
                                  ? 'Saved for connections without tmux.'
                                  : null,
                              prefixIcon: const Icon(Icons.play_arrow_outlined,
                                  size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ]),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, AppThemeExtension theme) {
    return Text(
      title,
      style: TextStyle(
        color: theme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
