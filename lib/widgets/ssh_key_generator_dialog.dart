import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/key_generator_service.dart';
import '../theme/app_theme.dart';

class SSHKeyGeneratorDialog extends StatefulWidget {
  const SSHKeyGeneratorDialog({super.key});

  static Future<GeneratedSSHKey?> show(BuildContext context) {
    return showDialog<GeneratedSSHKey>(
      context: context,
      builder: (_) => const SSHKeyGeneratorDialog(),
    );
  }

  @override
  State<SSHKeyGeneratorDialog> createState() => _SSHKeyGeneratorDialogState();
}

class _SSHKeyGeneratorDialogState extends State<SSHKeyGeneratorDialog> {
  final _commentController = TextEditingController(text: 'shell-lite');
  GeneratedSSHKey? _generatedKey;
  bool _isCopiedPublic = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _generate() {
    final comment = _commentController.text.trim().isNotEmpty
        ? _commentController.text.trim()
        : 'shell-lite';

    final key = SSHKeyGeneratorService.generateEd25519(comment: comment);
    setState(() {
      _generatedKey = key;
      _isCopiedPublic = false;
    });
  }

  void _copyPublicKey() async {
    if (_generatedKey == null) return;
    await Clipboard.setData(ClipboardData(text: _generatedKey!.publicKeyOpenSSH));
    setState(() => _isCopiedPublic = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopiedPublic = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return AlertDialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.primaryAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.key_rounded, color: theme.primaryAccent, size: 20),
          ),
          const SizedBox(width: 10),
          Text('SSH Key Generator', style: TextStyle(fontSize: 18, color: theme.textPrimary)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generates a high-security unencrypted Ed25519 key pair.',
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),

            // Key comment input
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Key Label / Comment',
                hintText: 'e.g. macbook-client or phone',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Regenerate',
                  onPressed: _generate,
                ),
              ),
              onSubmitted: (_) => _generate(),
            ),
            const SizedBox(height: 16),

            if (_generatedKey != null) ...[
              // Fingerprint badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.cardSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.fingerprint_rounded, size: 16, color: theme.secondaryAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _generatedKey!.fingerprint,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: theme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Public Key section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PUBLIC KEY (for remote server):',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _copyPublicKey,
                    icon: Icon(
                      _isCopiedPublic ? Icons.check_rounded : Icons.copy_rounded,
                      size: 14,
                      color: _isCopiedPublic ? theme.primaryAccent : theme.secondaryAccent,
                    ),
                    label: Text(
                      _isCopiedPublic ? 'Copied!' : 'Copy',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isCopiedPublic ? theme.primaryAccent : theme.secondaryAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border),
                ),
                child: SelectableText(
                  _generatedKey!.publicKeyOpenSSH,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '💡 Paste this public key into ~/.ssh/authorized_keys on your remote server.',
                style: TextStyle(color: theme.textSecondary, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Use Key in Profile'),
          onPressed: _generatedKey != null
              ? () => Navigator.of(context).pop(_generatedKey)
              : null,
        ),
      ],
    );
  }
}
