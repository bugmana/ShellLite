import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/auth_method.dart';
import '../models/server_profile.dart';
import '../providers/server_store.dart';
import '../services/key_generator_service.dart';
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
  String? _keyValidationError;
  String? _generatedPublicKey;
  bool _isCopiedPublic = false;
  Timer? _copyResetTimer;
  bool _isCopiedScript = false;
  Timer? _copyScriptResetTimer;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameController = TextEditingController(text: p?.displayName ?? '');
    _hostController = TextEditingController(text: p?.host ?? '');
    _portController = TextEditingController(text: p?.port.toString() ?? '${SSHConfig.defaultPort}');
    _usernameController = TextEditingController(text: p?.username ?? '');
    _passwordController = TextEditingController();
    _keyController = TextEditingController();
    _keyPassphraseController = TextEditingController();
    _initialCommandController = TextEditingController(text: p?.initialCommand ?? '');
    _tmuxSessionNameController = TextEditingController(text: p?.tmuxSessionName ?? '');
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
    _copyResetTimer?.cancel();
    _copyScriptResetTimer?.cancel();
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
      setState(() => _keyValidationError = e.toString().replaceAll('SSHKeyException: ', ''));
    }
  }

  void _clearKey() {
    _copyResetTimer?.cancel();
    setState(() {
      _keyController.clear();
      _keyPassphraseController.clear();
      _generatedPublicKey = null;
      _isCopiedPublic = false;
      _isCopiedScript = false;
      _obscureKey = false;
      _isKeyEncrypted = false;
      _keyValidationError = null;
    });
  }

  Future<void> _generateNewKey() async {
    final generated = SSHKeyGeneratorService.generateEd25519(comment: 'shell-lite');
    setState(() {
      _keyController.text = generated.privateKeyPem;
      _generatedPublicKey = generated.publicKeyOpenSSH;
      _isCopiedPublic = false;
      _isCopiedScript = false;
      _keyPassphraseController.clear();
      _obscureKey = false;
      _validateKey(generated.privateKeyPem);
    });

    await Clipboard.setData(ClipboardData(text: generated.publicKeyOpenSSH));

    if (mounted) {
      final theme = context.appTheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Generated Ed25519 key! Public key copied to clipboard.'),
              ),
            ],
          ),
          backgroundColor: theme.surface,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      final clean = _cleanKey(data.text!);
      setState(() {
        _keyController.text = clean;
        _obscureKey = false;
        _validateKey(clean);
      });
    }
  }

  void _copyPublicKey() {
    if (_generatedPublicKey == null) return;
    Clipboard.setData(ClipboardData(text: _generatedPublicKey!));
    _copyResetTimer?.cancel();
    setState(() => _isCopiedPublic = true);
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopiedPublic = false);
    });
  }

  void _copySetupScript() {
    if (_generatedPublicKey == null) return;
    final script =
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '${_generatedPublicKey!}' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys";
    Clipboard.setData(ClipboardData(text: script));
    _copyScriptResetTimer?.cancel();
    setState(() => _isCopiedScript = true);
    _copyScriptResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopiedScript = false);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    String? keyPassphrase;
    if (_authType == AuthType.sshKey) {
      final key = _cleanKey(_keyController.text);
      keyPassphrase = _keyPassphraseController.text;
      try {
        SSHKeyParser.parse(key, passphrase: keyPassphrase.isNotEmpty ? keyPassphrase : null);
      } catch (e) {
        setState(() => _keyValidationError = e.toString().replaceAll('SSHKeyException: ', ''));
        return;
      }
    }

    final store = context.read<ServerStore>();
    final port = int.tryParse(_portController.text.trim()) ?? SSHConfig.defaultPort;
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
      displayName: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: port,
      username: _usernameController.text.trim(),
      authMethod: authMethod,
      initialCommand: (!_persistSession && initialCmd.isNotEmpty) ? initialCmd : null,
      persistSession: _persistSession,
      tmuxSessionName: _persistSession && tmuxSession.isNotEmpty ? tmuxSession : null,
    );

    final credential = _authType == AuthType.password
        ? _passwordController.text.trim()
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

  Future<void> _parseClipboardSSHCommand() async {
    final data = await Clipboard.getData('text/plain');
    final raw = data?.text?.trim() ?? '';
    if (raw.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clipboard is empty')),
        );
      }
      return;
    }

    final regex = RegExp(
      r'(?:ssh\s+)?(?:-p\s*(?<port>\d+)\s+)?(?:-i\s*\S+\s+)?(?:(?<user>[a-zA-Z0-9._-]+)@)?(?<host>[a-zA-Z0-9.-]+)(?:\s+-p\s*(?<port2>\d+))?',
    );
    final match = regex.firstMatch(raw);
    if (match != null && match.namedGroup('host') != null) {
      HapticFeedback.mediumImpact();
      final host = match.namedGroup('host')!;
      final user = match.namedGroup('user') ?? 'root';
      final port = match.namedGroup('port') ?? match.namedGroup('port2') ?? '22';

      setState(() {
        _hostController.text = host;
        _usernameController.text = user;
        _portController.text = port;
        if (_nameController.text.isEmpty) {
          _nameController.text = '$host ($user)';
        }
      });
      if (mounted) {
        SemanticsService.sendAnnouncement(View.of(context), 'Server details populated from clipboard', TextDirection.ltr);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Populated from clipboard: $user@$host:$port'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not parse SSH command from clipboard')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProfile != null;
    final theme = context.appTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Server' : 'New Server'),
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
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // ── 1-Tap SSH Command Auto-Parser ───────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, AppTouchTarget.min),
                        side: BorderSide(color: theme.border),
                        foregroundColor: theme.primaryAccent,
                      ),
                      onPressed: _parseClipboardSSHCommand,
                      icon: const Icon(Icons.paste_rounded, size: 18),
                      label: const Text('Paste & Parse SSH Command from Clipboard'),
                    ),
                  ),

                  // ── Server Details Section ─────────────────────────────
                  _buildSectionHeader('SERVER DETAILS', theme),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      hintText: 'e.g. Production Web',
                      prefixIcon: Icon(Icons.label_outline_rounded, size: 20),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Display name is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'Host / IP Address',
                            hintText: 'e.g. 192.168.1.10',
                            prefixIcon: Icon(Icons.dns_outlined, size: 20),
                          ),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Host is required' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: 96.0,
                        child: TextFormField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '${SSHConfig.defaultPort}',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            final port = int.tryParse(val ?? '');
                            if (port == null || port < 1 || port > 65535) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'e.g. root or ubuntu',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                    autocorrect: false,
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Username is required' : null,
                  ),

                  const SizedBox(height: 24),

                  // ── Authentication Section ─────────────────────────────
                  _buildSectionHeader('AUTHENTICATION', theme),
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
                        label: Text('SSH Key'),
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
                          widget.existingProfile?.authMethod.type == AuthType.password,
                      theme: theme,
                    )
                  else ...[
                    KeyAuthSection(
                      keyController: _keyController,
                      isEditing: isEditing,
                      hasStoredKey: isEditing &&
                          widget.existingProfile?.authMethod.type == AuthType.sshKey,
                      obscureKey: _obscureKey,
                      onToggleObscureKey: () => setState(() => _obscureKey = !_obscureKey),
                      onClearKey: _clearKey,
                      onGenerateKey: _generateNewKey,
                      onPasteKey: _pasteFromClipboard,
                      onKeyChanged: (val) {
                        _validateKey(val);
                        setState(() {});
                      },
                      generatedPublicKey: _generatedPublicKey,
                      isCopiedPublic: _isCopiedPublic,
                      onCopyPublicKey: _copyPublicKey,
                      isCopiedScript: _isCopiedScript,
                      onCopySetupScript: _copySetupScript,
                      theme: theme,
                    ),
                    PassphraseSection(
                      controller: _keyPassphraseController,
                      isEditing: isEditing,
                      isKeyEncrypted: _isKeyEncrypted,
                      hasStoredPassphrase: isEditing &&
                          widget.existingProfile?.authMethod is SSHKeyAuth &&
                          (widget.existingProfile!.authMethod as SSHKeyAuth).isPassphraseProtected,
                      validationError: _keyValidationError,
                      onChanged: (val) => _validateKey(_keyController.text, val),
                      onClear: () => _validateKey(_keyController.text),
                      theme: theme,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Persistent Session (tmux) Section ───────────────────
                  _buildSectionHeader('PERSISTENT SESSION (TMUX)', theme),
                  const SizedBox(height: 8),
                  TmuxConfigPanel(
                    persistSession: _persistSession,
                    onPersistChanged: (val) => setState(() => _persistSession = val),
                    sessionNameController: _tmuxSessionNameController,
                    theme: theme,
                  ),

                  const SizedBox(height: 24),

                  // ── Startup Command Section ─────────────────────────────
                  _buildSectionHeader('STARTUP (OPTIONAL)', theme),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('initialCommandField'),
                    controller: _initialCommandController,
                    enabled: !_persistSession,
                    decoration: const InputDecoration(
                      labelText: 'Initial Command',
                      hintText: 'e.g. htop or cd /var/www',
                      prefixIcon: Icon(Icons.play_arrow_outlined, size: 20),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
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
