import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Top banner showing reconnection status and reconnect button when disconnected or error.
class TerminalConnectionBanner extends StatelessWidget {
  final bool wasConnected;
  final bool isConnecting;
  final VoidCallback onReconnect;
  final AppThemeExtension theme;

  const TerminalConnectionBanner({
    super.key,
    required this.wasConnected,
    required this.isConnecting,
    required this.onReconnect,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Semantics(
        liveRegion: true,
        label: wasConnected ? 'Connection lost.' : 'Connection failed.',
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.cardSurface.withValues(alpha: 0.94),
            border: Border(
              bottom: BorderSide(
                color: theme.warning.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.warning, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  wasConnected ? 'Connection lost.' : 'Connection failed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryAccent,
                  foregroundColor: AppTheme.computeOnPrimary(theme.primaryAccent),
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: isConnecting ? null : onReconnect,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isConnecting)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.computeOnPrimary(theme.primaryAccent),
                        ),
                      )
                    else
                      const Icon(Icons.refresh_rounded, size: 16),
                    const SizedBox(width: 4),
                    const Text('Reconnect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
