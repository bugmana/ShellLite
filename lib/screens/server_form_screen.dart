import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../models/auth_method.dart';
import '../models/server_profile.dart';
import '../providers/server_store.dart';
import '../services/key_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/ssh_key_generator_dialog.dart';

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
  late final TextEditingController _initialCommandController;
  late final TextEditingController _tmuxSessionNameController;

  AuthType _authType = AuthType.password;
  bool _obscurePassword = true;
  bool _obscureKey = false;
  bool _isLoadingCredential = false;
  bool _persistSession = false;
  String? _keyValidationError;

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
    final cred = await context.read<ServerStore>().getCredential(profile);
    if (mounted && cred != null) {
      if (profile.authMethod.type == AuthType.password) {
        _passwordController.text = cred;
      } else {
        _keyController.text = cred;
      }
    }
    if (mounted) {
      setState(() => _isLoadingCredential = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _keyController.dispose();
    _initialCommandController.dispose();
    _tmuxSessionNameController.dispose();
    super.dispose();
  }

  String _cleanKey(String val) {
    return val.trim().replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  void _validateKey(String val) {
    final clean = _cleanKey(val);
    if (clean.isEmpty) {
      setState(() => _keyValidationError = null);
      return;
    }
    try {
      SSHKeyParser.parse(clean);
      setState(() => _keyValidationError = null);
    } catch (e) {
      setState(() => _keyValidationError = e.toString().replaceAll('SSHKeyException: ', ''));
    }
  }

  void _clearKey() {
    setState(() {
      _keyController.clear();
      _obscureKey = false;
      _keyValidationError = null;
    });
  }

  Future<void> _generateNewKey() async {
    final generated = await SSHKeyGeneratorDialog.show(context);
    if (generated != null) {
      setState(() {
        _keyController.text = generated.privateKeyPem;
        _obscureKey = false;
        _validateKey(generated.privateKeyPem);
      });
      if (mounted) {
        final theme = context.appTheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Generated Ed25519 key applied!'),
            backgroundColor: theme.surface,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_authType == AuthType.sshKey) {
      final key = _cleanKey(_keyController.text);
      try {
        SSHKeyParser.parse(key);
      } catch (e) {
        setState(() => _keyValidationError = e.toString().replaceAll('SSHKeyException: ', ''));
        return;
      }
    }

    final store = context.read<ServerStore>();
    final port = int.tryParse(_portController.text.trim()) ?? SSHConfig.defaultPort;
    final id = widget.existingProfile?.id ?? const Uuid().v4();
    final tag = StorageConfig.buildCredentialTag(id);

    final authMethod = _authType == AuthType.password
        ? PasswordAuth(credentialTag: tag)
        : SSHKeyAuth(privateKeyTag: tag);

    final initialCmd = _initialCommandController.text.trim();
    final tmuxSession = _tmuxSessionNameController.text.trim();

    final profile = ServerProfile(
      id: id,
      displayName: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: port,
      username: _usernameController.text.trim(),
      authMethod: authMethod,
      initialCommand: initialCmd.isNotEmpty ? initialCmd : null,
      persistSession: _persistSession,
      tmuxSessionName: _persistSession && tmuxSession.isNotEmpty ? tmuxSession : null,
    );

    final credential = _authType == AuthType.password
        ? _passwordController.text.trim()
        : _cleanKey(_keyController.text);

    if (widget.existingProfile == null) {
      await store.addProfile(profile, credential: credential);
    } else {
      await store.updateProfile(
        profile,
        newCredential: credential.isNotEmpty ? credential : null,
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
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Server Details Section ─────────────────────────────
                  _buildSectionHeader('SERVER DETAILS', theme),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
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
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
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

                  if (_authType == AuthType.password) ...[
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: isEditing && _passwordController.text.isEmpty
                            ? '•••••••• (Stored password)'
                            : 'Enter password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_passwordController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                tooltip: 'Clear password',
                                onPressed: () => setState(() => _passwordController.clear()),
                              ),
                            IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ],
                        ),
                      ),
                      validator: (val) {
                        final hasStoredPass = isEditing &&
                            widget.existingProfile!.authMethod.type == AuthType.password;
                        if (!hasStoredPass && (val == null || val.isEmpty)) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          'OpenSSH Private Key',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_keyController.text.trim().isNotEmpty) ...[
                              if (_obscureKey)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => setState(() => _obscureKey = false),
                                  icon: Icon(Icons.visibility_outlined, size: 14, color: theme.secondaryAccent),
                                  label: Text('Show', style: TextStyle(fontSize: 12, color: theme.secondaryAccent)),
                                )
                              else
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => setState(() => _obscureKey = true),
                                  icon: Icon(Icons.visibility_off_outlined, size: 14, color: theme.secondaryAccent),
                                  label: Text('Hide', style: TextStyle(fontSize: 12, color: theme.secondaryAccent)),
                                ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _clearKey,
                                icon: Icon(Icons.clear_rounded, size: 14, color: theme.error),
                                label: Text('Clear', style: TextStyle(fontSize: 12, color: theme.error)),
                              ),
                            ],
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _generateNewKey,
                              icon: Icon(Icons.auto_awesome_rounded, size: 14, color: theme.primaryAccent),
                              label: Text('Generate', style: TextStyle(fontSize: 12, color: theme.primaryAccent)),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _pasteFromClipboard,
                              icon: const Icon(Icons.paste_rounded, size: 14),
                              label: const Text('Paste', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_obscureKey && _keyController.text.trim().isNotEmpty) ...[
                      Material(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _obscureKey = false),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lock_rounded, color: theme.primaryAccent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Secure Private Key Stored',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: theme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '••••••••••••••••••••••••••••••••••••',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: theme.textSecondary,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.cardSurface,
                                    foregroundColor: theme.secondaryAccent,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: BorderSide(color: theme.border),
                                    ),
                                  ),
                                  onPressed: () => setState(() => _obscureKey = false),
                                  icon: const Icon(Icons.visibility_outlined, size: 15),
                                  label: const Text('Show Key', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _keyController,
                        maxLines: 8,
                        minLines: 4,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----',
                        ),
                        onChanged: (val) {
                          _validateKey(val);
                          setState(() {});
                        },
                        validator: (val) {
                          final hasStoredKey = isEditing &&
                              widget.existingProfile!.authMethod.type == AuthType.sshKey;
                          if (!hasStoredKey && (val == null || val.trim().isEmpty)) {
                            return 'Private key is required';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_keyValidationError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _keyValidationError!,
                        style: TextStyle(color: theme.error, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Supports unencrypted OpenSSH keys (Ed25519, ECDSA, RSA). Encrypted keys with passphrases are not supported.',
                      style: TextStyle(color: theme.textSecondary, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Persistent Session (tmux) Section ───────────────────
                  _buildSectionHeader('PERSISTENT SESSION (TMUX)', theme),
                  const SizedBox(height: 8),
                  Material(
                    color: theme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: _persistSession ? theme.primaryAccent.withValues(alpha: 0.5) : theme.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          title: Text(
                            'Persistent Session (tmux)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: theme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Keeps background processes running across reconnections.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          value: _persistSession,
                          activeThumbColor: theme.primaryAccent,
                          onChanged: (val) {
                            setState(() {
                              _persistSession = val;
                            });
                          },
                        ),
                        if (_persistSession) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: TextFormField(
                              controller: _tmuxSessionNameController,
                              decoration: const InputDecoration(
                                labelText: 'Session Name (optional, defaults to "shelllite")',
                                hintText: 'shelllite',
                                prefixIcon: Icon(Icons.terminal_rounded, size: 20),
                              ),
                              autocorrect: false,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Startup Command Section ─────────────────────────────
                  _buildSectionHeader('STARTUP (OPTIONAL)', theme),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _initialCommandController,
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
