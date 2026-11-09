import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class KeyAuthSection extends StatelessWidget {
  final TextEditingController keyController;
  final bool isEditing;
  final bool hasStoredKey;
  final bool obscureKey;
  final VoidCallback onToggleObscureKey;
  final VoidCallback onClearKey;
  final ValueChanged<String> onKeyChanged;
  final AppThemeExtension theme;

  const KeyAuthSection(
      {super.key,
      required this.keyController,
      required this.isEditing,
      required this.hasStoredKey,
      required this.obscureKey,
      required this.onToggleObscureKey,
      required this.onClearKey,
      required this.onKeyChanged,
      required this.theme});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 4, children: [
          TextButton(
              onPressed: onToggleObscureKey,
              child: Text(obscureKey ? 'Show key' : 'Hide key')),
          TextButton(onPressed: onClearKey, child: const Text('Clear key')),
        ]),
        if (obscureKey && keyController.text.isNotEmpty)
          const Padding(
              padding: EdgeInsets.all(16), child: Text('Private key hidden'))
        else
          TextFormField(
              controller: keyController,
              minLines: 4,
              maxLines: 8,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                  labelText: 'Private key',
                  hintText: 'Paste your OpenSSH private key'),
              onChanged: onKeyChanged,
              validator: (value) =>
                  !hasStoredKey && (value == null || value.trim().isEmpty)
                      ? 'Private key is required'
                      : null),
      ]);
}
