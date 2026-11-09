import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/clipboard_feedback.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  static const canonicalUrl = 'https://strandberg.dev/privacy/shelllite/';

  Future<void> _copyPolicy(BuildContext context) async {
    try {
      await Clipboard.setData(const ClipboardData(text: canonicalUrl));
      final showMessage = await ClipboardFeedback.showSuccessMessage;
      if (context.mounted && showMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Policy link copied')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not copy. Try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Privacy')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _section(context, 'Stored on your device',
              'Server profiles and preferences are saved locally. Passwords, private keys, and passphrases use platform secure storage.'),
          _section(context, 'Connections',
              'ShellLite connects to the SSH servers you choose. The Web app uses a WebSocket bridge. Files you upload are sent to your selected server.'),
          _section(context, 'No tracking',
              'ShellLite has no analytics, advertising, or crash-reporting service. Terminal output is not saved as a session log by the app.'),
          _section(context, 'Delete a server',
              'Deleting a server removes its saved profile and associated credentials from ShellLite.'),
          _section(context, 'Publisher and contact',
              'Aron Strandberg, Stockholm, Sweden.\naron@strandberg.dev'),
          TextButton(
              onPressed: () => _copyPolicy(context),
              child: const Text(canonicalUrl)),
          const Text('Tap to copy the policy link.'),
        ]),
      );

  Widget _section(BuildContext context, String title, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(text),
        ]),
      );
}
