import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// SSH Key authentication input section for ServerFormScreen.
class KeyAuthSection extends StatelessWidget {
  final TextEditingController keyController;
  final bool isEditing;
  final bool hasStoredKey;
  final bool obscureKey;
  final VoidCallback onToggleObscureKey;
  final VoidCallback onClearKey;
  final VoidCallback onGenerateKey;
  final VoidCallback onPasteKey;
  final ValueChanged<String> onKeyChanged;
  final String? generatedPublicKey;
  final bool isCopiedPublic;
  final VoidCallback onCopyPublicKey;
  final bool isCopiedScript;
  final VoidCallback onCopySetupScript;
  final AppThemeExtension theme;

  const KeyAuthSection({
    super.key,
    required this.keyController,
    required this.isEditing,
    required this.hasStoredKey,
    required this.obscureKey,
    required this.onToggleObscureKey,
    required this.onClearKey,
    required this.onGenerateKey,
    required this.onPasteKey,
    required this.onKeyChanged,
    required this.generatedPublicKey,
    required this.isCopiedPublic,
    required this.onCopyPublicKey,
    required this.isCopiedScript,
    required this.onCopySetupScript,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                if (keyController.text.trim().isNotEmpty) ...[
                  if (obscureKey)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onToggleObscureKey,
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
                      onPressed: onToggleObscureKey,
                      icon: Icon(Icons.visibility_off_outlined, size: 14, color: theme.secondaryAccent),
                      label: Text('Hide', style: TextStyle(fontSize: 12, color: theme.secondaryAccent)),
                    ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onClearKey,
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
                  onPressed: onGenerateKey,
                  icon: Icon(Icons.auto_awesome_rounded, size: 14, color: theme.primaryAccent),
                  label: Text('Generate', style: TextStyle(fontSize: 12, color: theme.primaryAccent)),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onPasteKey,
                  icon: const Icon(Icons.paste_rounded, size: 14),
                  label: const Text('Paste', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (obscureKey && keyController.text.trim().isNotEmpty) ...[
          Material(
            color: theme.surface,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggleObscureKey,
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
                      onPressed: onToggleObscureKey,
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
            controller: keyController,
            maxLines: 8,
            minLines: 4,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
            decoration: const InputDecoration(
              hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----',
            ),
            onChanged: onKeyChanged,
            validator: (val) {
              if (!hasStoredKey && (val == null || val.trim().isEmpty)) {
                return 'Private key is required';
              }
              return null;
            },
          ),
        ],
        if (generatedPublicKey != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.primaryAccent.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.key_rounded, size: 16, color: theme.primaryAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Public Key (Add to ~/.ssh/authorized_keys)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.border),
                  ),
                  child: SelectableText(
                    generatedPublicKey!,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: theme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.cardSurface,
                        foregroundColor: isCopiedPublic ? theme.success : theme.primaryAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: isCopiedPublic ? theme.success : theme.border,
                          ),
                        ),
                      ),
                      onPressed: onCopyPublicKey,
                      icon: Icon(
                        isCopiedPublic ? Icons.check_circle_rounded : Icons.copy_rounded,
                        size: 14,
                      ),
                      label: Text(
                        isCopiedPublic ? 'Copied!' : 'Copy Public Key',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.cardSurface,
                        foregroundColor: isCopiedScript ? theme.success : theme.secondaryAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: isCopiedScript ? theme.success : theme.border,
                          ),
                        ),
                      ),
                      onPressed: onCopySetupScript,
                      icon: Icon(
                        isCopiedScript ? Icons.check_circle_rounded : Icons.bolt_rounded,
                        size: 14,
                      ),
                      label: Text(
                        isCopiedScript ? 'Copied Script!' : 'Copy 1-Line Setup Script',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
