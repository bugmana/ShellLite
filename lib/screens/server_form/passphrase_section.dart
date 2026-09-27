import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Passphrase input section for encrypted SSH keys in ServerFormScreen.
class PassphraseSection extends StatefulWidget {
  final TextEditingController controller;
  final bool isEditing;
  final bool isKeyEncrypted;
  final bool hasStoredPassphrase;
  final String? validationError;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final AppThemeExtension theme;

  const PassphraseSection({
    super.key,
    required this.controller,
    required this.isEditing,
    required this.isKeyEncrypted,
    required this.hasStoredPassphrase,
    required this.validationError,
    required this.onChanged,
    required this.onClear,
    required this.theme,
  });

  @override
  State<PassphraseSection> createState() => _PassphraseSectionState();
}

class _PassphraseSectionState extends State<PassphraseSection> {
  bool _obscureKeyPassphrase = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscureKeyPassphrase,
          decoration: InputDecoration(
            labelText: widget.isKeyEncrypted
                ? 'Key Passphrase (Required)'
                : 'Key Passphrase (Optional)',
            hintText: widget.isEditing &&
                    widget.controller.text.isEmpty &&
                    widget.hasStoredPassphrase
                ? '•••••••• (Stored passphrase)'
                : 'Enter passphrase if key is encrypted',
            prefixIcon: const Icon(Icons.password_rounded, size: 20),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    tooltip: 'Clear passphrase',
                    onPressed: () {
                      setState(() => widget.controller.clear());
                      widget.onClear();
                    },
                  ),
                IconButton(
                  icon: Icon(
                    _obscureKeyPassphrase
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  tooltip: _obscureKeyPassphrase ? 'Show passphrase' : 'Hide passphrase',
                  onPressed: () =>
                      setState(() => _obscureKeyPassphrase = !_obscureKeyPassphrase),
                ),
              ],
            ),
          ),
          onChanged: (val) {
            setState(() {});
            widget.onChanged(val);
          },
        ),
        if (widget.validationError != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.validationError!,
            style: TextStyle(color: widget.theme.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'Supports OpenSSH keys (Ed25519, ECDSA, RSA) and password-protected / encrypted private keys.',
          style: TextStyle(color: widget.theme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
