import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String canonicalUrl = 'https://strandberg.dev/privacy/shelllite/';

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _buildHeroCard(context, theme),
          const SizedBox(height: 16),
          _buildPolicyCard(
            theme: theme,
            icon: Icons.do_not_disturb_on_total_silence_rounded,
            title: 'Zero Data Collection & Telemetry',
            description:
                'ShellLite does not collect, record, track, or sell any personal data, session logs, or metadata. There are zero third-party analytics SDKs, advertising frameworks, or crash beacons integrated.',
          ),
          _buildPolicyCard(
            theme: theme,
            icon: Icons.lock_outline_rounded,
            title: 'Hardware-Backed Encryption',
            description:
                'All connection profiles, usernames, and authentication secrets (passwords, private keys, passphrases) are stored on your local device and encrypted using OS hardware security:\n• Android: Android KeyStore (AES-GCM-256)\n• iOS: Apple Keychain via Secure Enclave\n• Desktop / Web: Sandboxed secure storage',
          ),
          _buildPolicyCard(
            theme: theme,
            icon: Icons.alt_route_rounded,
            title: 'Direct Peer-to-Peer SSH',
            description:
                'When connecting, network packets stream directly between your device and your specified SSH host (or via your configured WebSocket bridge for browser sessions). Traffic is never routed through or proxied by third-party relays.',
          ),
          _buildPolicyCard(
            theme: theme,
            icon: Icons.vpn_key_outlined,
            title: 'On-Device Key Generation',
            description:
                'Cryptographic key pairs (e.g. Ed25519) generated in ShellLite are produced entirely on-device using local cryptographic randomness. Private keys never leave your physical device.',
          ),
          _buildPolicyCard(
            theme: theme,
            icon: Icons.speed_rounded,
            title: 'Transient Server Telemetry',
            description:
                'Live system health statistics (CPU, RAM, Disk, Uptime) are retrieved exclusively over your authenticated SSH connection and maintained in volatile memory for UI rendering. They are never written to disk or sent externally.',
          ),
          _buildPolicyCard(
            theme: theme,
            icon: Icons.delete_outline_rounded,
            title: 'Data Sovereignty & Deletion',
            description:
                'You maintain total ownership of your configurations. Deleting a server profile permanently purges all associated keys and credentials. Uninstalling the app removes all stored data completely.',
          ),
          _buildPolicyCard(
            theme: theme,
            icon: Icons.contact_support_outlined,
            title: 'Publisher & Contact',
            description:
                'ShellLite is published by Aron Strandberg (Stockholm, Sweden).\nInquiries or security disclosures can be sent directly to aron@strandberg.dev.',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, AppThemeExtension theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.primaryAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_user_rounded, color: theme.primaryAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy & Security First',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Client-side execution & hardware encryption',
                      style: TextStyle(color: theme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'ShellLite operates strictly on your personal device. Your SSH keys, passwords, and terminal sessions never touch external servers or third-party tracking services.',
            style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              Clipboard.setData(const ClipboardData(text: canonicalUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Official policy URL copied to clipboard'),
                  backgroundColor: theme.surface,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, color: theme.primaryAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      canonicalUrl,
                      style: TextStyle(
                        color: theme.primaryAccent,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.copy_rounded, color: theme.textSecondary, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard({
    required AppThemeExtension theme,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.border),
            ),
            child: Icon(icon, color: theme.secondaryAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
