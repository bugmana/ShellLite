import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Password authentication input section for ServerFormScreen.
class PasswordAuthSection extends StatefulWidget {
  final TextEditingController controller;
  final bool isEditing;
  final bool hasStoredPassword;
  final AppThemeExtension theme;

  const PasswordAuthSection({
    super.key,
    required this.controller,
    required this.isEditing,
    required this.hasStoredPassword,
    required this.theme,
  });

  @override
  State<PasswordAuthSection> createState() => _PasswordAuthSectionState();
}

class _PasswordAuthSectionState extends State<PasswordAuthSection> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: widget.isEditing && widget.controller.text.isEmpty
            ? '•••••••• (Stored password)'
            : 'Enter password',
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                tooltip: 'Clear password',
                onPressed: () => setState(() => widget.controller.clear()),
              ),
            IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
              ),
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ],
        ),
      ),
      validator: (val) {
        if (!widget.hasStoredPassword && (val == null || val.isEmpty)) {
          return 'Password is required';
        }
        return null;
      },
    );
  }
}
