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
  late final TextEditingController _credentialController;
  late final TextEditingController _initialCommandController;

  AuthType _authType = AuthType.password;
  bool _obscurePassword = true;
  bool _obscureKey = true;
  bool _isLoadingCredential = false;
  String? _keyValidationError;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameController = TextEditingController(text: p?.displayName ?? '');
    _hostController = TextEditingController(text: p?.host ?? '');
    _portController = TextEditingController(text: p?.port.toString() ?? '${SSHConfig.defaultPort}');
    _usernameController = TextEditingController(text: p?.username ?? '');
    _credentialController = TextEditingController();
    _initialCommandController = TextEditingController(text: p?.initialCommand ?? '');

    if (p != null) {
      _authType = p.authMethod.type;
      _loadExistingCredential(p);
    }
  }

  Future<void> _loadExistingCredential(ServerProfile profile) async {
    setState(() => _isLoadingCredential = true);
    final cred = await context.read<ServerStore>().getCredential(profile);
    if (mounted && cred != null) {
      _credentialController.text = cred;
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
    _credentialController.dispose();
    _initialCommandController.dispose();
    super.dispose();
  }

  void _validateKey(String val) {
    if (val.trim().isEmpty) {
      setState(() => _keyValidationError = null);
      return;
    }
    try {
      SSHKeyParser.parse(val);
      setState(() => _keyValidationError = null);
    } catch (e) {
      setState(() => _keyValidationError = e.toString().replaceAll('SSHKeyException: ', ''));
    }
  }

  Future<void> _generateNewKey() async {
    final generated = await SSHKeyGeneratorDialog.show(context);
    if (generated != null) {
      setState(() {
        _credentialController.text = generated.privateKeyPem;
        _obscureKey = true;
        _validateKey(generated.privateKeyPem);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generated Ed25519 key applied!'),
            backgroundColor: AppTheme.surface,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null) {
      _credentialController.text = data.text!;
      _validateKey(data.text!);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_authType == AuthType.sshKey) {
      final key = _credentialController.text.trim();
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

    final profile = ServerProfile(
      id: id,
      displayName: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: port,
      username: _usernameController.text.trim(),
      authMethod: authMethod,
      initialCommand: initialCmd.isNotEmpty ? initialCmd : null,
    );

    if (widget.existingProfile == null) {
      await store.addProfile(profile, credential: _credentialController.text.trim());
    } else {
      await store.updateProfile(
        profile,
        newCredential: _credentialController.text.trim().isNotEmpty
            ? _credentialController.text.trim()
            : null,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingProfile != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Server' : 'New Server'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppTheme.terminalGreen,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoadingCredential
          ? const Center(child: CircularProgressIndicator(color: AppTheme.terminalGreen))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Server Details Section ─────────────────────────────
                  _buildSectionHeader('SERVER DETAILS'),
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
                  _buildSectionHeader('AUTHENTICATION'),
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
                      selectedBackgroundColor: AppTheme.accentGreen,
                      selectedForegroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_authType == AuthType.password) ...[
                    TextFormField(
                      controller: _credentialController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter SSH password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (val) {
                        if (!isEditing && (val == null || val.isEmpty)) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'OpenSSH Private Key',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_obscureKey && _credentialController.text.trim().isNotEmpty) ...[
                              TextButton.icon(
                                onPressed: () => setState(() => _obscureKey = true),
                                icon: const Icon(Icons.visibility_off_outlined, size: 15, color: AppTheme.accentBlue),
                                label: const Text('Hide Key', style: TextStyle(fontSize: 12, color: AppTheme.accentBlue)),
                              ),
                              const SizedBox(width: 2),
                            ],
                            TextButton.icon(
                              onPressed: _generateNewKey,
                              icon: const Icon(Icons.auto_awesome_rounded, size: 15, color: AppTheme.terminalGreen),
                              label: const Text('Generate', style: TextStyle(fontSize: 12, color: AppTheme.terminalGreen)),
                            ),
                            const SizedBox(width: 2),
                            TextButton.icon(
                              onPressed: _pasteFromClipboard,
                              icon: const Icon(Icons.paste_rounded, size: 15),
                              label: const Text('Paste', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_obscureKey && _credentialController.text.trim().isNotEmpty) ...[
                      Material(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _obscureKey = false),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_rounded, color: AppTheme.terminalGreen, size: 20),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Secure Private Key Stored',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '••••••••••••••••••••••••••••••••••••',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.cardSurface,
                                    foregroundColor: AppTheme.accentBlue,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: const BorderSide(color: AppTheme.border),
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
                        controller: _credentialController,
                        maxLines: 6,
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
                          if (!isEditing && (val == null || val.trim().isEmpty)) {
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
                        style: const TextStyle(color: AppTheme.errorRed, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Supports unencrypted OpenSSH keys (Ed25519, ECDSA, RSA). Encrypted keys with passphrases are not supported.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Startup Command Section ─────────────────────────────
                  _buildSectionHeader('STARTUP (OPTIONAL)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _initialCommandController,
                    decoration: const InputDecoration(
                      labelText: 'Initial Command',
                      hintText: 'e.g. tmux attach || tmux new',
                      prefixIcon: Icon(Icons.play_arrow_outlined, size: 20),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
