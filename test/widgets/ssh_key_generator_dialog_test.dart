import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/widgets/ssh_key_generator_dialog.dart';

void main() {
  testWidgets('SSHKeyGeneratorDialog generates key and renders public key details', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SSHKeyGeneratorDialog(),
        ),
      ),
    );

    expect(find.text('SSH Key Generator'), findsOneWidget);
    expect(find.text('PUBLIC KEY (for remote server):'), findsOneWidget);
    expect(find.text('Use Key in Profile'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);

    // Verify generated key preview contains ssh-ed25519
    expect(find.textContaining('ssh-ed25519'), findsWidgets);
  });
}
